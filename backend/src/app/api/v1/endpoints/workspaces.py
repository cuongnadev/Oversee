import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_workspace_role
from app.db.session import get_db
from app.models.enums import RoleType
from app.models.membership import WorkspaceMember
from app.models.user import User
from app.schemas.membership import (
    WorkspaceMemberCreate,
    WorkspaceMemberResponse,
    WorkspaceMemberUpdate,
)
from app.schemas.project import (
    ProjectCreate,
    ProjectPageResponse,
    ProjectResponse,
)
from app.schemas.workspace import (
    WorkspaceCreate,
    WorkspaceResponse,
    WorkspaceUpdate,
)
from app.services.project import (
    create_project,
    list_workspace_projects,
)
from app.services.workspace import (
    add_workspace_member,
    create_workspace,
    delete_workspace,
    get_workspace_by_id,
    list_user_workspaces,
    list_workspace_members,
    remove_workspace_member,
    update_workspace,
    update_workspace_member_role,
)

router = APIRouter()


# ---------------------------------------------------------------------------
# Workspace CRUD Endpoints (#86)
# ---------------------------------------------------------------------------
@router.post(
    "",
    response_model=WorkspaceResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new workspace",
    description=(
        "Create a new workspace organization. The authenticated user automatically "
        "becomes the OWNER of the workspace."
    ),
)
def create_new_workspace(
    data: WorkspaceCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> WorkspaceResponse:
    """Create a new workspace with the current user as owner."""
    return create_workspace(db=db, user=current_user, data=data)


@router.get(
    "",
    response_model=list[WorkspaceResponse],
    status_code=status.HTTP_200_OK,
    summary="List user workspaces",
    description="Retrieve all workspaces where the currently authenticated user is an active member.",
)
def list_workspaces(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> list[WorkspaceResponse]:
    """List workspaces that the current user belongs to."""
    return list_user_workspaces(db=db, user=current_user)


@router.get(
    "/{workspace_id}",
    response_model=WorkspaceResponse,
    status_code=status.HTTP_200_OK,
    summary="Get workspace by ID",
    description="Retrieve detailed information for a specific workspace. Requires VIEWER role or higher.",
)
def get_workspace(
    workspace_id: uuid.UUID,
    member: Annotated[
        WorkspaceMember, Depends(require_workspace_role(RoleType.VIEWER))
    ],
    db: Annotated[Session, Depends(get_db)],
) -> WorkspaceResponse:
    """Get workspace details."""
    return get_workspace_by_id(db=db, workspace_id=workspace_id)


@router.patch(
    "/{workspace_id}",
    response_model=WorkspaceResponse,
    status_code=status.HTTP_200_OK,
    summary="Update workspace",
    description="Update workspace details (name, slug, description). Requires ADMIN role or higher.",
)
def update_existing_workspace(
    workspace_id: uuid.UUID,
    data: WorkspaceUpdate,
    member: Annotated[WorkspaceMember, Depends(require_workspace_role(RoleType.ADMIN))],
    db: Annotated[Session, Depends(get_db)],
) -> WorkspaceResponse:
    """Update workspace details."""
    workspace = get_workspace_by_id(db=db, workspace_id=workspace_id)
    return update_workspace(db=db, workspace=workspace, data=data)


@router.delete(
    "/{workspace_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete workspace",
    description="Soft delete a workspace. Requires ADMIN role or higher.",
)
def delete_existing_workspace(
    workspace_id: uuid.UUID,
    member: Annotated[WorkspaceMember, Depends(require_workspace_role(RoleType.ADMIN))],
    db: Annotated[Session, Depends(get_db)],
) -> None:
    """Soft delete workspace."""
    workspace = get_workspace_by_id(db=db, workspace_id=workspace_id)
    delete_workspace(db=db, workspace=workspace)


# ---------------------------------------------------------------------------
# Workspace Membership Endpoints (#87)
# ---------------------------------------------------------------------------
@router.get(
    "/{workspace_id}/members",
    response_model=list[WorkspaceMemberResponse],
    status_code=status.HTTP_200_OK,
    summary="List workspace members",
    description="List all members in the specified workspace. Requires VIEWER role or higher.",
)
def get_workspace_members(
    workspace_id: uuid.UUID,
    member: Annotated[
        WorkspaceMember, Depends(require_workspace_role(RoleType.VIEWER))
    ],
    db: Annotated[Session, Depends(get_db)],
) -> list[WorkspaceMemberResponse]:
    """Retrieve all members of the workspace."""
    return list_workspace_members(db=db, workspace_id=workspace_id)


@router.post(
    "/{workspace_id}/members",
    response_model=WorkspaceMemberResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add member to workspace",
    description=(
        "Add a new user to the workspace with the specified role. "
        "Requires ADMIN role or higher. Only OWNER can assign OWNER role."
    ),
)
def add_member_to_workspace(
    workspace_id: uuid.UUID,
    data: WorkspaceMemberCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    member: Annotated[WorkspaceMember, Depends(require_workspace_role(RoleType.ADMIN))],
    db: Annotated[Session, Depends(get_db)],
) -> WorkspaceMemberResponse:
    """Add or invite a member to the workspace."""
    return add_workspace_member(
        db=db,
        actor=current_user,
        workspace_id=workspace_id,
        data=data,
    )


@router.patch(
    "/{workspace_id}/members/{user_id}",
    response_model=WorkspaceMemberResponse,
    status_code=status.HTTP_200_OK,
    summary="Update workspace member role",
    description=(
        "Update the role of a workspace member. Requires ADMIN role or higher. "
        "ADMIN cannot modify an OWNER role. Cannot demote the last OWNER."
    ),
)
def update_member_role(
    workspace_id: uuid.UUID,
    user_id: uuid.UUID,
    data: WorkspaceMemberUpdate,
    current_user: Annotated[User, Depends(get_current_user)],
    member: Annotated[WorkspaceMember, Depends(require_workspace_role(RoleType.ADMIN))],
    db: Annotated[Session, Depends(get_db)],
) -> WorkspaceMemberResponse:
    """Update role for an existing workspace member."""
    return update_workspace_member_role(
        db=db,
        actor=current_user,
        workspace_id=workspace_id,
        target_user_id=user_id,
        data=data,
    )


@router.delete(
    "/{workspace_id}/members/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Remove workspace member",
    description=(
        "Remove a member from the workspace, or leave the workspace (self-removal). "
        "Requires ADMIN role to remove others. Cannot remove the last OWNER."
    ),
)
def remove_member(
    workspace_id: uuid.UUID,
    user_id: uuid.UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    member: Annotated[
        WorkspaceMember, Depends(require_workspace_role(RoleType.VIEWER))
    ],
    db: Annotated[Session, Depends(get_db)],
) -> None:
    """Remove a member or self-leave from the workspace."""
    remove_workspace_member(
        db=db,
        actor=current_user,
        workspace_id=workspace_id,
        target_user_id=user_id,
    )


# ---------------------------------------------------------------------------
# Workspace Project Endpoints (#90)
# ---------------------------------------------------------------------------
@router.post(
    "/{workspace_id}/projects",
    response_model=ProjectResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create project in workspace",
    description=(
        "Create a new project in the specified workspace. Requires workspace ADMIN role or higher. "
        "Project key must be unique within the workspace. The creator is automatically assigned Project OWNER."
    ),
)
def create_project_in_workspace(
    workspace_id: uuid.UUID,
    data: ProjectCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    member: Annotated[WorkspaceMember, Depends(require_workspace_role(RoleType.ADMIN))],
    db: Annotated[Session, Depends(get_db)],
) -> ProjectResponse:
    """Create a new project in the workspace."""
    return create_project(
        db=db,
        user=current_user,
        workspace_id=workspace_id,
        data=data,
    )


@router.get(
    "/{workspace_id}/projects",
    response_model=ProjectPageResponse,
    status_code=status.HTTP_200_OK,
    summary="List projects in workspace",
    description=(
        "List all projects belonging to the workspace with pagination. "
        "Requires workspace VIEWER role or higher."
    ),
)
def list_projects_in_workspace(
    workspace_id: uuid.UUID,
    member: Annotated[
        WorkspaceMember, Depends(require_workspace_role(RoleType.VIEWER))
    ],
    db: Annotated[Session, Depends(get_db)],
    page: int = Query(default=1, ge=1, description="Page number (1-based)"),
    page_size: int = Query(default=20, ge=1, le=100, description="Items per page"),
    include_archived: bool = Query(
        default=False, description="Include archived projects"
    ),
) -> ProjectPageResponse:
    """List projects in workspace with pagination."""
    items, total = list_workspace_projects(
        db=db,
        workspace_id=workspace_id,
        page=page,
        page_size=page_size,
        include_archived=include_archived,
    )
    total_pages = (total + page_size - 1) // page_size if total > 0 else 0
    return ProjectPageResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
    )
