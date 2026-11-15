import uuid

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.enums import RoleType
from app.models.membership import ProjectMember
from app.models.project import Project
from app.models.user import User
from app.models.workspace import Workspace
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
