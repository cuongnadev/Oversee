import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import (
    get_current_user,
    require_project_role,
)
from app.db.session import get_db
from app.models.enums import RoleType
from app.models.membership import ProjectMember, WorkspaceMember
from app.models.project import Project
from app.models.user import User
from app.schemas.membership import (
    ProjectMemberCreate,
    ProjectMemberResponse,
    ProjectMemberUpdate,
)
from app.schemas.project import (
    ProjectResponse,
    ProjectUpdate,
)
from app.services.project import (
    add_project_member,
    archive_project,
    get_project_by_id,
    list_project_members,
    remove_project_member,
    restore_project,
    update_project,
    update_project_member_role,
)

router = APIRouter()


# ---------------------------------------------------------------------------
# Project CRUD Endpoints (#90)
# ---------------------------------------------------------------------------
@router.get(
    "/{project_id}",
    response_model=ProjectResponse,
    status_code=status.HTTP_200_OK,
    summary="Get project by ID",
    description="Retrieve details for a project. Requires project membership or workspace admin access.",
)
def get_project(
    project_id: uuid.UUID,
    member: Annotated[ProjectMember, Depends(require_project_role(RoleType.VIEWER))],
    db: Annotated[Session, Depends(get_db)],
) -> ProjectResponse:
    """Retrieve details of a single project."""
    return get_project_by_id(db=db, project_id=project_id)


@router.patch(
    "/{project_id}",
    response_model=ProjectResponse,
    status_code=status.HTTP_200_OK,
    summary="Update project",
    description="Update project details (name, key, description). Requires ADMIN role or higher.",
)
def update_existing_project(
    project_id: uuid.UUID,
    data: ProjectUpdate,
    member: Annotated[ProjectMember, Depends(require_project_role(RoleType.ADMIN))],
    db: Annotated[Session, Depends(get_db)],
) -> ProjectResponse:
    """Update project details."""
    project = get_project_by_id(db=db, project_id=project_id)
    return update_project(db=db, project=project, data=data)


@router.delete(
    "/{project_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Archive (soft delete) project",
    description="Soft delete (archive) a project. Requires ADMIN role or higher.",
)
def archive_existing_project(
    project_id: uuid.UUID,
    member: Annotated[ProjectMember, Depends(require_project_role(RoleType.ADMIN))],
    db: Annotated[Session, Depends(get_db)],
) -> None:
    """Archive a project."""
    project = get_project_by_id(db=db, project_id=project_id)
    archive_project(db=db, project=project)


@router.post(
    "/{project_id}/restore",
    response_model=ProjectResponse,
    status_code=status.HTTP_200_OK,
    summary="Restore archived project",
    description="Restore a soft-deleted (archived) project. Requires workspace ADMIN role or higher.",
)
def restore_archived_project(
    project_id: uuid.UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> ProjectResponse:
    """Restore an archived project."""
    project = db.scalar(select(Project).where(Project.id == project_id))
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found.",
        )

    # Check workspace admin permissions
    ws_member = db.scalar(
        select(WorkspaceMember).where(
            WorkspaceMember.workspace_id == project.workspace_id,
            WorkspaceMember.user_id == current_user.id,
        )
    )
    if not ws_member or ws_member.role not in (RoleType.OWNER, RoleType.ADMIN):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to restore project.",
        )

    return restore_project(db=db, project=project)


# ---------------------------------------------------------------------------
# Project Member Management Endpoints (#91)
# ---------------------------------------------------------------------------
@router.get(
    "/{project_id}/members",
    response_model=list[ProjectMemberResponse],
    status_code=status.HTTP_200_OK,
    summary="List project members",
    description="List all members in the specified project. Requires project VIEWER role or higher.",
)
def get_project_members(
    project_id: uuid.UUID,
    member: Annotated[ProjectMember, Depends(require_project_role(RoleType.VIEWER))],
    db: Annotated[Session, Depends(get_db)],
) -> list[ProjectMemberResponse]:
    """Retrieve all members of the project."""
    return list_project_members(db=db, project_id=project_id)


@router.post(
    "/{project_id}/members",
    response_model=ProjectMemberResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add member to project",
    description=(
        "Add an existing workspace user to the project with the specified role. "
        "User must already belong to the parent workspace. Requires project ADMIN role or higher."
    ),
)
def add_member_to_project(
    project_id: uuid.UUID,
    data: ProjectMemberCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    member: Annotated[ProjectMember, Depends(require_project_role(RoleType.ADMIN))],
    db: Annotated[Session, Depends(get_db)],
) -> ProjectMemberResponse:
    """Add a member to the project."""
    return add_project_member(
        db=db,
        actor=current_user,
        project_id=project_id,
        data=data,
    )


@router.patch(
    "/{project_id}/members/{user_id}",
    response_model=ProjectMemberResponse,
    status_code=status.HTTP_200_OK,
    summary="Update project member role",
    description=(
        "Update the role of a project member. Requires project ADMIN role or higher. "
        "ADMIN cannot modify an OWNER role. Cannot demote the last project OWNER."
    ),
)
def update_member_role_in_project(
    project_id: uuid.UUID,
    user_id: uuid.UUID,
    data: ProjectMemberUpdate,
    current_user: Annotated[User, Depends(get_current_user)],
    member: Annotated[ProjectMember, Depends(require_project_role(RoleType.ADMIN))],
    db: Annotated[Session, Depends(get_db)],
) -> ProjectMemberResponse:
    """Update role for an existing project member."""
    return update_project_member_role(
        db=db,
        actor=current_user,
        project_id=project_id,
        target_user_id=user_id,
        data=data,
    )


@router.delete(
    "/{project_id}/members/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Remove project member",
    description=(
        "Remove a member from the project, or leave the project (self-removal). "
        "Requires ADMIN role to remove others. Cannot remove the last project OWNER."
    ),
)
def remove_member_from_project(
    project_id: uuid.UUID,
    user_id: uuid.UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    member: Annotated[ProjectMember, Depends(require_project_role(RoleType.VIEWER))],
    db: Annotated[Session, Depends(get_db)],
) -> None:
    """Remove a member or self-leave from the project."""
    remove_project_member(
        db=db,
        actor=current_user,
        project_id=project_id,
        target_user_id=user_id,
    )
