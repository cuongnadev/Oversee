import uuid

from fastapi import HTTPException, status
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session, selectinload

from app.models.enums import RoleType
from app.models.membership import ProjectMember, WorkspaceMember
from app.models.project import Project
from app.models.user import User
from app.models.workspace import Workspace
from app.schemas.membership import WorkspaceMemberCreate, WorkspaceMemberUpdate
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


# ---------------------------------------------------------------------------
# Workspace Membership Services (#87)
# ---------------------------------------------------------------------------
def add_workspace_member(
    db: Session,
    actor: User,
    workspace_id: uuid.UUID,
    data: WorkspaceMemberCreate,
) -> WorkspaceMember:
    """
    Add a new member to the workspace.

    :param db: Active database session.
    :param actor: Authenticated user initiating the action.
    :param workspace_id: ID of the workspace.
    :param data: Validated membership creation payload.
    :return: Newly created WorkspaceMember entity.
    :raises HTTPException: 403 Forbidden on permission violations, 404 if user not found,
                           409 Conflict if user is already a member.
    """
    actor_member = db.scalar(
        select(WorkspaceMember).where(
            WorkspaceMember.workspace_id == workspace_id,
            WorkspaceMember.user_id == actor.id,
        )
    )
    if not actor_member or actor_member.role not in (
        RoleType.OWNER,
        RoleType.ADMIN,
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to add members.",
        )

    if data.role == RoleType.OWNER and actor_member.role != RoleType.OWNER:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only workspace owners can assign the OWNER role.",
        )

    if data.user_id is not None:
        target_user = db.scalar(
            select(User).where(
                User.id == data.user_id,
                User.deleted_at.is_(None),
            )
        )
    else:
        target_user = db.scalar(
            select(User).where(
                User.email == str(data.email).lower().strip(),
                User.deleted_at.is_(None),
            )
        )

    if target_user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )

    if not target_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot add an inactive user.",
        )

    existing = db.scalar(
        select(WorkspaceMember).where(
            WorkspaceMember.workspace_id == workspace_id,
            WorkspaceMember.user_id == target_user.id,
        )
    )
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User is already a member of this workspace.",
        )

    member = WorkspaceMember(
        workspace_id=workspace_id,
        user_id=target_user.id,
        role=data.role,
    )
    db.add(member)
    db.commit()
    db.refresh(member)
    member.user = target_user
    return member


def list_workspace_members(
    db: Session,
    workspace_id: uuid.UUID,
) -> list[WorkspaceMember]:
    """
    Retrieve all members of a workspace.

    :param db: Active database session.
    :param workspace_id: ID of the workspace.
    :return: List of WorkspaceMember entities with related User data loaded.
    """
    stmt = (
        select(WorkspaceMember)
        .options(selectinload(WorkspaceMember.user))
        .where(WorkspaceMember.workspace_id == workspace_id)
        .order_by(WorkspaceMember.created_at.asc())
    )
    return list(db.scalars(stmt).all())


def update_workspace_member_role(
    db: Session,
    actor: User,
    workspace_id: uuid.UUID,
    target_user_id: uuid.UUID,
    data: WorkspaceMemberUpdate,
) -> WorkspaceMember:
    """
    Update a member's role within the workspace.

    :param db: Active database session.
    :param actor: Authenticated user initiating the role change.
    :param workspace_id: ID of the workspace.
    :param target_user_id: ID of the member whose role is being changed.
    :param data: Validated update payload with the new role.
    :return: Updated WorkspaceMember entity.
    """
    actor_member = db.scalar(
        select(WorkspaceMember).where(
            WorkspaceMember.workspace_id == workspace_id,
            WorkspaceMember.user_id == actor.id,
        )
    )
    if not actor_member or actor_member.role not in (
        RoleType.OWNER,
        RoleType.ADMIN,
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to update member roles.",
        )

    target_member = db.scalar(
        select(WorkspaceMember)
        .options(selectinload(WorkspaceMember.user))
        .where(
            WorkspaceMember.workspace_id == workspace_id,
            WorkspaceMember.user_id == target_user_id,
        )
    )
    if not target_member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Member not found in this workspace.",
        )

    # Admin cannot touch an Owner's role or promote to Owner
    if actor_member.role == RoleType.ADMIN:
        if target_member.role == RoleType.OWNER:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot modify the role of a workspace owner.",
            )
        if data.role == RoleType.OWNER:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only workspace owners can assign the OWNER role.",
            )

    # Protect against demoting the last remaining OWNER
    if target_member.role == RoleType.OWNER and data.role != RoleType.OWNER:
        owner_count = (
            db.scalar(
                select(func.count(WorkspaceMember.id)).where(
                    WorkspaceMember.workspace_id == workspace_id,
                    WorkspaceMember.role == RoleType.OWNER,
                )
            )
            or 0
        )
        if owner_count <= 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot demote the last owner of the workspace.",
            )

    target_member.role = data.role
    db.add(target_member)
    db.commit()
    db.refresh(target_member)
    return target_member


def remove_workspace_member(
    db: Session,
    actor: User,
    workspace_id: uuid.UUID,
    target_user_id: uuid.UUID,
) -> None:
    """
    Remove a member from the workspace (or allow self-leave).

    :param db: Active database session.
    :param actor: Authenticated user initiating removal.
    :param workspace_id: ID of the workspace.
    :param target_user_id: ID of the user being removed.
    """
    target_member = db.scalar(
        select(WorkspaceMember).where(
            WorkspaceMember.workspace_id == workspace_id,
            WorkspaceMember.user_id == target_user_id,
        )
    )
    if not target_member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Member not found in this workspace.",
        )

    actor_member = db.scalar(
        select(WorkspaceMember).where(
            WorkspaceMember.workspace_id == workspace_id,
            WorkspaceMember.user_id == actor.id,
        )
    )
    if not actor_member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Workspace not found.",
        )

    is_self_removal = actor.id == target_user_id

    if not is_self_removal:
        if actor_member.role not in (RoleType.OWNER, RoleType.ADMIN):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions to remove members.",
            )
        if actor_member.role == RoleType.ADMIN and target_member.role == RoleType.OWNER:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot remove a workspace owner.",
            )

    # Protect against removing the last OWNER
    if target_member.role == RoleType.OWNER:
        owner_count = (
            db.scalar(
                select(func.count(WorkspaceMember.id)).where(
                    WorkspaceMember.workspace_id == workspace_id,
                    WorkspaceMember.role == RoleType.OWNER,
                )
            )
            or 0
        )
        if owner_count <= 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot remove the last owner of the workspace.",
            )

    # Clean up project memberships for this user in projects belonging to this workspace
    project_ids_subquery = select(Project.id).where(
        Project.workspace_id == workspace_id
    )
    db.execute(
        delete(ProjectMember).where(
            ProjectMember.project_id.in_(project_ids_subquery),
            ProjectMember.user_id == target_user_id,
        )
    )

    db.delete(target_member)
    db.commit()
