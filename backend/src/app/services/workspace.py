import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.enums import RoleType
from app.models.membership import WorkspaceMember
from app.models.user import User
from app.models.workspace import Workspace
from app.schemas.workspace import WorkspaceCreate, WorkspaceUpdate


def create_workspace(
    db: Session,
    user: User,
    data: WorkspaceCreate,
) -> Workspace:
    """
    Create a new workspace and automatically establish the creator as the OWNER.

    :param db: Active database session.
    :param user: Authenticated user creating the workspace.
    :param data: Validated workspace creation payload.
    :return: Newly created Workspace entity.
    :raises HTTPException: 409 Conflict if workspace with same slug already exists.
    """
    existing = db.scalar(
        select(Workspace).where(
            Workspace.slug == data.slug,
            Workspace.deleted_at.is_(None),
        )
    )
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Workspace with slug '{data.slug}' already exists.",
        )

    workspace = Workspace(
        name=data.name,
        slug=data.slug,
        description=data.description,
        owner_id=user.id,
    )
    db.add(workspace)
    db.flush()

    # The creator automatically becomes the workspace OWNER
    membership = WorkspaceMember(
        workspace_id=workspace.id,
        user_id=user.id,
        role=RoleType.OWNER,
    )
    db.add(membership)
    db.commit()
    db.refresh(workspace)
    return workspace


def list_user_workspaces(
    db: Session,
    user: User,
) -> list[Workspace]:
    """
    Retrieve only the workspaces where the user is an active member.

    :param db: Active database session.
    :param user: Authenticated user.
    :return: List of Workspace entities ordered by creation date descending.
    """
    stmt = (
        select(Workspace)
        .join(WorkspaceMember, WorkspaceMember.workspace_id == Workspace.id)
        .where(
            WorkspaceMember.user_id == user.id,
            Workspace.deleted_at.is_(None),
        )
        .order_by(Workspace.created_at.desc())
    )
    return list(db.scalars(stmt).all())


def get_workspace_by_id(
    db: Session,
    workspace_id: uuid.UUID,
) -> Workspace:
    """
    Retrieve an active workspace by its unique identifier.

    :param db: Active database session.
    :param workspace_id: UUID of the workspace.
    :return: Workspace entity.
    :raises HTTPException: 404 Not Found if workspace does not exist or is soft deleted.
    """
    workspace = db.scalar(
        select(Workspace).where(
            Workspace.id == workspace_id,
            Workspace.deleted_at.is_(None),
        )
    )
    if workspace is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Workspace not found.",
        )
    return workspace


def update_workspace(
    db: Session,
    workspace: Workspace,
    data: WorkspaceUpdate,
) -> Workspace:
    """
    Update workspace details (name, slug, description).

    :param db: Active database session.
    :param workspace: Workspace entity to update.
    :param data: Validated update payload.
    :return: Updated Workspace entity.
    :raises HTTPException: 409 Conflict if new slug is taken by another active workspace.
    """
    update_dict = data.model_dump(exclude_unset=True)

    if "slug" in update_dict and update_dict["slug"] != workspace.slug:
        existing = db.scalar(
            select(Workspace).where(
                Workspace.slug == update_dict["slug"],
                Workspace.id != workspace.id,
                Workspace.deleted_at.is_(None),
            )
        )
        if existing is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Workspace with slug '{update_dict['slug']}' already exists.",
            )

    for field, value in update_dict.items():
        setattr(workspace, field, value)

    db.add(workspace)
    db.commit()
    db.refresh(workspace)
    return workspace


def delete_workspace(
    db: Session,
    workspace: Workspace,
) -> None:
    """
    Soft delete a workspace.

    :param db: Active database session.
    :param workspace: Workspace entity to delete.
    """
    workspace.soft_delete()
    db.add(workspace)
    db.commit()
