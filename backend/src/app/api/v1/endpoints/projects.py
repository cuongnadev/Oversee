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
from app.schemas.project import (
    ProjectResponse,
    ProjectUpdate,
)
from app.services.project import (
    archive_project,
    get_project_by_id,
    restore_project,
    update_project,
)

router = APIRouter()


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
