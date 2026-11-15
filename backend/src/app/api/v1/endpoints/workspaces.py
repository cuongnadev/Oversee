import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_workspace_role
from app.db.session import get_db
from app.models.enums import RoleType
from app.models.membership import WorkspaceMember
from app.models.user import User
from app.schemas.workspace import (
    WorkspaceCreate,
    WorkspaceResponse,
    WorkspaceUpdate,
)
from app.services.workspace import (
    create_workspace,
    delete_workspace,
    get_workspace_by_id,
    list_user_workspaces,
    update_workspace,
)

router = APIRouter()


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
    workspace = create_workspace(db=db, user=current_user, data=data)
    return workspace


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
