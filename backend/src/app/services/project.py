import uuid

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.core.permissions import ROLE_HIERARCHY, has_required_role
from app.models.enums import RoleType
from app.models.membership import ProjectMember, WorkspaceMember
from app.models.project import Project
from app.models.user import User
from app.models.workspace import Workspace
from app.schemas.membership import ProjectMemberCreate, ProjectMemberUpdate
from app.schemas.project import ProjectCreate, ProjectUpdate


def create_project(
    db: Session,
    user: User,
    workspace_id: uuid.UUID,
    data: ProjectCreate,
) -> Project:
    """
    Create a new project within a workspace and assign creator as Project OWNER.

    :param db: Active database session.
    :param user: Authenticated user initiating creation.
    :param workspace_id: ID of the workspace.
    :param data: Validated project creation payload.
    :return: Newly created Project entity.
    :raises HTTPException: 404 if workspace does not exist, 409 if project key already exists.
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

    # Check key uniqueness within workspace
    existing_key = db.scalar(
        select(Project).where(
            Project.workspace_id == workspace_id,
            Project.key == data.key,
            Project.deleted_at.is_(None),
        )
    )
    if existing_key is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Project with key '{data.key}' already exists in this workspace.",
        )

    project = Project(
        name=data.name,
        key=data.key,
        description=data.description,
        workspace_id=workspace_id,
    )
    db.add(project)
    db.flush()

    # Creator automatically becomes Project OWNER
    membership = ProjectMember(
        project_id=project.id,
        user_id=user.id,
        role=RoleType.OWNER,
    )
    db.add(membership)
    db.commit()
    db.refresh(project)
    return project


def list_workspace_projects(
    db: Session,
    workspace_id: uuid.UUID,
    page: int = 1,
    page_size: int = 20,
    include_archived: bool = False,
) -> tuple[list[Project], int]:
    """
    List projects belonging to a workspace with pagination.

    :param db: Active database session.
    :param workspace_id: ID of the workspace.
    :param page: 1-based page number.
    :param page_size: Items per page.
    :param include_archived: Whether to include soft-deleted projects.
    :return: Tuple of (list of Project items, total count).
    """
    base_filter = [Project.workspace_id == workspace_id]
    if not include_archived:
        base_filter.append(Project.deleted_at.is_(None))

    total = db.scalar(select(func.count(Project.id)).where(*base_filter)) or 0

    offset = (page - 1) * page_size
    stmt = (
        select(Project)
        .where(*base_filter)
        .order_by(Project.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    items = list(db.scalars(stmt).all())
    return items, total


def get_project_by_id(
    db: Session,
    project_id: uuid.UUID,
) -> Project:
    """
    Retrieve active project by ID.

    :param db: Active database session.
    :param project_id: ID of the project.
    :return: Project entity.
    :raises HTTPException: 404 if project does not exist or is soft deleted.
    """
    project = db.scalar(
        select(Project).where(
            Project.id == project_id,
            Project.deleted_at.is_(None),
        )
    )
    if project is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found.",
        )
    return project


def update_project(
    db: Session,
    project: Project,
    data: ProjectUpdate,
) -> Project:
    """
    Update project attributes (name, key, description).

    :param db: Active database session.
    :param project: Project entity to update.
    :param data: Validated update payload.
    :return: Updated Project entity.
    :raises HTTPException: 409 if new key is already in use in the workspace.
    """
    update_dict = data.model_dump(exclude_unset=True)

    if "key" in update_dict and update_dict["key"] != project.key:
        existing = db.scalar(
            select(Project).where(
                Project.workspace_id == project.workspace_id,
                Project.key == update_dict["key"],
                Project.id != project.id,
                Project.deleted_at.is_(None),
            )
        )
        if existing is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Project with key '{update_dict['key']}' already exists in this workspace.",
            )

    for field, value in update_dict.items():
        setattr(project, field, value)

    db.add(project)
    db.commit()
    db.refresh(project)
    return project


def archive_project(
    db: Session,
    project: Project,
) -> None:
    """
    Soft delete (archive) a project.

    :param db: Active database session.
    :param project: Project entity to archive.
    """
    project.soft_delete()
    db.add(project)
    db.commit()


def restore_project(
    db: Session,
    project: Project,
) -> Project:
    """
    Restore an archived project.

    :param db: Active database session.
    :param project: Project entity to restore.
    :return: Restored Project entity.
    """
    project.restore()
    db.add(project)
    db.commit()
    db.refresh(project)
    return project


# ---------------------------------------------------------------------------
# Project Member Management Services (#91)
# ---------------------------------------------------------------------------
def _resolve_effective_role(
    db: Session, project: Project, user_id: uuid.UUID
) -> RoleType | None:
    pm = db.scalar(
        select(ProjectMember).where(
            ProjectMember.project_id == project.id,
            ProjectMember.user_id == user_id,
        )
    )
    ws = db.scalar(
        select(WorkspaceMember).where(
            WorkspaceMember.workspace_id == project.workspace_id,
            WorkspaceMember.user_id == user_id,
        )
    )
    role = pm.role if pm else None
    if (
        ws
        and ws.role in (RoleType.OWNER, RoleType.ADMIN)
        and (
            role is None or ROLE_HIERARCHY.get(ws.role, 0) > ROLE_HIERARCHY.get(role, 0)
        )
    ):
        role = ws.role
    return role


def add_project_member(
    db: Session,
    actor: User,
    project_id: uuid.UUID,
    data: ProjectMemberCreate,
) -> ProjectMember:
    """
    Add a member to the project. Target user must already belong to the parent workspace.

    :param db: Active database session.
    :param actor: Authenticated user initiating the addition.
    :param project_id: ID of the project.
    :param data: Validated project membership creation payload.
    :return: Newly created ProjectMember entity with user loaded.
    :raises HTTPException: 400 if user not in workspace, 403 on permission violation,
                           404 if user not found, 409 if already a member.
    """
    project = get_project_by_id(db, project_id)

    # Actor permission verification
    actor_role = _resolve_effective_role(db, project, actor.id)
    if not actor_role or not has_required_role(actor_role, RoleType.ADMIN):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to add project members.",
        )

    if data.role == RoleType.OWNER and actor_role != RoleType.OWNER:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only project owners can assign the OWNER role.",
        )

    # Resolve target user
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

    # Crucial Requirement: "Chỉ thêm được user đã thuộc workspace"
    ws_membership = db.scalar(
        select(WorkspaceMember).where(
            WorkspaceMember.workspace_id == project.workspace_id,
            WorkspaceMember.user_id == target_user.id,
        )
    )
    if ws_membership is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User must be a member of the workspace before being added to a project.",
        )

    # Check if already a member of this project
    existing_pm = db.scalar(
        select(ProjectMember).where(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == target_user.id,
        )
    )
    if existing_pm is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User is already a member of this project.",
        )

    new_member = ProjectMember(
        project_id=project.id,
        user_id=target_user.id,
        role=data.role,
    )
    db.add(new_member)
    db.commit()
    db.refresh(new_member)
    new_member.user = target_user
    return new_member


def list_project_members(
    db: Session,
    project_id: uuid.UUID,
) -> list[ProjectMember]:
    """
    Retrieve all members of a project.

    :param db: Active database session.
    :param project_id: ID of the project.
    :return: List of ProjectMember entities with related User data loaded.
    """
    get_project_by_id(db, project_id)
    stmt = (
        select(ProjectMember)
        .options(selectinload(ProjectMember.user))
        .where(ProjectMember.project_id == project_id)
        .order_by(ProjectMember.created_at.asc())
    )
    return list(db.scalars(stmt).all())


def update_project_member_role(
    db: Session,
    actor: User,
    project_id: uuid.UUID,
    target_user_id: uuid.UUID,
    data: ProjectMemberUpdate,
) -> ProjectMember:
    """
    Update a member's role within the project.

    :param db: Active database session.
    :param actor: Authenticated user initiating the role change.
    :param project_id: ID of the project.
    :param target_user_id: ID of the member whose role is being changed.
    :param data: Validated update payload with the new role.
    :return: Updated ProjectMember entity.
    """
    project = get_project_by_id(db, project_id)

    # Actor permission verification
    actor_role = _resolve_effective_role(db, project, actor.id)
    if not actor_role or not has_required_role(actor_role, RoleType.ADMIN):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to update project member roles.",
        )

    target_member = db.scalar(
        select(ProjectMember)
        .options(selectinload(ProjectMember.user))
        .where(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == target_user_id,
        )
    )
    if not target_member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Member not found in this project.",
        )

    # Admin cannot touch an Owner's role or promote to Owner
    if actor_role != RoleType.OWNER:
        if target_member.role == RoleType.OWNER:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot modify the role of a project owner.",
            )
        if data.role == RoleType.OWNER:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only project owners can assign the OWNER role.",
            )

    # Prevent demoting the last Project OWNER
    if target_member.role == RoleType.OWNER and data.role != RoleType.OWNER:
        owner_count = (
            db.scalar(
                select(func.count(ProjectMember.id)).where(
                    ProjectMember.project_id == project_id,
                    ProjectMember.role == RoleType.OWNER,
                )
            )
            or 0
        )
        if owner_count <= 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot demote the last owner of the project.",
            )

    target_member.role = data.role
    db.add(target_member)
    db.commit()
    db.refresh(target_member)
    return target_member


def remove_project_member(
    db: Session,
    actor: User,
    project_id: uuid.UUID,
    target_user_id: uuid.UUID,
) -> None:
    """
    Remove a member from the project (or allow self-leave).

    :param db: Active database session.
    :param actor: Authenticated user initiating removal.
    :param project_id: ID of the project.
    :param target_user_id: ID of the user being removed.
    """
    project = get_project_by_id(db, project_id)

    target_member = db.scalar(
        select(ProjectMember).where(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == target_user_id,
        )
    )
    if not target_member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Member not found in this project.",
        )

    is_self_removal = actor.id == target_user_id

    if not is_self_removal:
        actor_role = _resolve_effective_role(db, project, actor.id)
        if not actor_role or not has_required_role(actor_role, RoleType.ADMIN):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions to remove project members.",
            )

        if actor_role != RoleType.OWNER and target_member.role == RoleType.OWNER:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot remove a project owner.",
            )

    # Protect against removing the last Project OWNER
    if target_member.role == RoleType.OWNER:
        owner_count = (
            db.scalar(
                select(func.count(ProjectMember.id)).where(
                    ProjectMember.project_id == project_id,
                    ProjectMember.role == RoleType.OWNER,
                )
            )
            or 0
        )
        if owner_count <= 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot remove the last owner of the project.",
            )

    db.delete(target_member)
    db.commit()
