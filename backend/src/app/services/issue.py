import math
import uuid

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.core.permissions import ROLE_HIERARCHY, role_has_permission
from app.models.enums import IssueType, Permission, RoleType
from app.models.issue import Issue
from app.models.membership import ProjectMember, WorkspaceMember
from app.models.project import Project
from app.models.sprint import Sprint
from app.models.user import User
from app.schemas.issue import IssueCreate, IssuePageResponse, IssueUpdate


def _resolve_effective_role(
    db: Session, project_id: uuid.UUID, user_id: uuid.UUID
) -> RoleType | None:
    """Resolve a user's effective role on a project, including workspace inheritance."""
    pm = db.scalar(
        select(ProjectMember).where(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == user_id,
        )
    )
    project = db.scalar(
        select(Project).where(
            Project.id == project_id,
            Project.deleted_at.is_(None),
        )
    )
    ws_role: RoleType | None = None
    if project:
        ws_member = db.scalar(
            select(WorkspaceMember).where(
                WorkspaceMember.workspace_id == project.workspace_id,
                WorkspaceMember.user_id == user_id,
            )
        )
        if ws_member:
            ws_role = ws_member.role

    role = pm.role if pm else None
    if (
        ws_role
        and ws_role in (RoleType.OWNER, RoleType.ADMIN)
        and (
            role is None or ROLE_HIERARCHY.get(ws_role, 0) > ROLE_HIERARCHY.get(role, 0)
        )
    ):
        role = ws_role
    return role


def _is_user_project_member(
    db: Session, project_id: uuid.UUID, user_id: uuid.UUID
) -> bool:
    """Check if a user is an active member of the project or workspace owner/admin."""
    pm = db.scalar(
        select(ProjectMember).where(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == user_id,
        )
    )
    if pm is not None:
        return True

    project = db.scalar(
        select(Project).where(
            Project.id == project_id,
            Project.deleted_at.is_(None),
        )
    )
    if project:
        ws_member = db.scalar(
            select(WorkspaceMember).where(
                WorkspaceMember.workspace_id == project.workspace_id,
                WorkspaceMember.user_id == user_id,
                WorkspaceMember.role.in_([RoleType.OWNER, RoleType.ADMIN]),
            )
        )
        if ws_member is not None:
            return True

    return False


def _check_circular_parent(
    db: Session, issue_id: uuid.UUID, new_parent_id: uuid.UUID
) -> None:
    """Detect circular parent-child relationships up the hierarchy tree."""
    current_parent_id: uuid.UUID | None = new_parent_id
    visited = {issue_id}
    while current_parent_id is not None:
        if current_parent_id in visited:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Circular parent-child relationship detected.",
            )
        visited.add(current_parent_id)
        parent_obj = db.scalar(
            select(Issue.parent_id).where(
                Issue.id == current_parent_id,
                Issue.deleted_at.is_(None),
            )
        )
        current_parent_id = parent_obj


def _soft_delete_issue_recursive(db: Session, issue: Issue) -> None:
    """Soft delete an issue and all active sub-issues recursively."""
    issue.soft_delete()
    for child in issue.sub_issues:
        if not child.is_deleted:
            _soft_delete_issue_recursive(db, child)


def _restore_issue_recursive(db: Session, issue: Issue) -> None:
    """Restore a soft-deleted issue and all its deleted sub-issues recursively."""
    issue.restore()
    for child in issue.sub_issues:
        if child.is_deleted:
            _restore_issue_recursive(db, child)


def get_next_issue_number(db: Session, project_id: uuid.UUID) -> int:
    """Calculate the next sequential issue number for a project."""
    max_num = db.scalar(
        select(func.coalesce(func.max(Issue.issue_number), 0)).where(
            Issue.project_id == project_id
        )
    )
    return (max_num or 0) + 1


def create_issue(
    db: Session,
    actor: User,
    project_id: uuid.UUID,
    data: IssueCreate,
) -> Issue:
    """
    Create a new issue/task in the specified project.

    :param db: Active database session.
    :param actor: Authenticated user creating the issue.
    :param project_id: Target project UUID.
    :param data: Validated issue creation payload.
    :return: Newly created Issue entity with parent and sub-issues preloaded.
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

    actor_role = _resolve_effective_role(db, project_id, actor.id)
    if not actor_role or not role_has_permission(actor_role, Permission.ISSUE_CREATE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to create issues in this project.",
        )

    # Determine issue number
    if data.issue_number is not None:
        existing = db.scalar(
            select(Issue).where(
                Issue.project_id == project_id,
                Issue.issue_number == data.issue_number,
            )
        )
        if existing is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Issue number already exists in this project.",
            )
        issue_number = data.issue_number
    else:
        issue_number = get_next_issue_number(db, project_id)

    # Validate assignee if provided
    if data.assignee_id is not None:
        assignee = db.scalar(
            select(User).where(
                User.id == data.assignee_id,
                User.deleted_at.is_(None),
            )
        )
        if assignee is None or not assignee.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Assignee not found or inactive.",
            )
        if not _is_user_project_member(db, project_id, data.assignee_id):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Assignee must be a member of the project.",
            )

    # Validate parent if provided
    if data.parent_id is not None:
        parent = db.scalar(
            select(Issue).where(
                Issue.id == data.parent_id,
                Issue.deleted_at.is_(None),
            )
        )
        if parent is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Parent issue not found.",
            )
        if parent.project_id != project_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Parent issue must belong to the same project.",
            )
        if parent.type == IssueType.SUBTASK:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="A subtask cannot have child issues.",
            )

    # Subtasks require a parent issue
    if data.type == IssueType.SUBTASK and data.parent_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A subtask must have a parent issue.",
        )

    # Validate sprint if provided
    if data.sprint_id is not None:
        sprint = db.scalar(
            select(Sprint).where(
                Sprint.id == data.sprint_id,
                Sprint.deleted_at.is_(None),
            )
        )
        if sprint is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Sprint not found.",
            )
        if sprint.project_id != project_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Sprint must belong to the same project.",
            )

    new_issue = Issue(
        project_id=project_id,
        issue_number=issue_number,
        title=data.title,
        description=data.description,
        type=data.type,
        status=data.status,
        priority=data.priority,
        reporter_id=actor.id,
        assignee_id=data.assignee_id,
        parent_id=data.parent_id,
        sprint_id=data.sprint_id,
        backlog_rank=data.backlog_rank if data.backlog_rank is not None else 0.0,
    )
    db.add(new_issue)
    db.commit()
    db.refresh(new_issue)

    return get_issue_by_id(db, new_issue.id)


def get_issue_by_id(db: Session, issue_id: uuid.UUID) -> Issue:
    """Retrieve an active issue by its ID with parent and sub-issues preloaded."""
    issue = db.scalar(
        select(Issue)
        .options(
            selectinload(Issue.parent),
            selectinload(Issue.sub_issues),
        )
        .where(
            Issue.id == issue_id,
            Issue.deleted_at.is_(None),
        )
    )
    if issue is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Issue not found.",
        )
    return issue


def list_project_issues(
    db: Session,
    project_id: uuid.UUID,
    page: int = 1,
    page_size: int = 20,
) -> IssuePageResponse:
    """List non-deleted issues for a project with pagination."""
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

    total = (
        db.scalar(
            select(func.count(Issue.id)).where(
                Issue.project_id == project_id,
                Issue.deleted_at.is_(None),
            )
        )
        or 0
    )

    offset = (page - 1) * page_size
    items = list(
        db.scalars(
            select(Issue)
            .options(
                selectinload(Issue.parent),
                selectinload(Issue.sub_issues),
            )
            .where(
                Issue.project_id == project_id,
                Issue.deleted_at.is_(None),
            )
            .order_by(Issue.issue_number.asc())
            .offset(offset)
            .limit(page_size)
        ).all()
    )

    total_pages = math.ceil(total / page_size) if total > 0 else 1

    return IssuePageResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
    )


def update_issue(
    db: Session,
    issue: Issue,
    actor: User,
    data: IssueUpdate,
) -> Issue:
    """Update issue details with integrity and permission checks."""
    actor_role = _resolve_effective_role(db, issue.project_id, actor.id)
    if not actor_role or not role_has_permission(actor_role, Permission.ISSUE_UPDATE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to update this issue.",
        )

    update_dict = data.model_dump(exclude_unset=True)

    if "title" in update_dict:
        issue.title = data.title

    if "description" in update_dict:
        issue.description = data.description

    if "status" in update_dict:
        issue.status = data.status

    if "priority" in update_dict:
        issue.priority = data.priority

    if "type" in update_dict and data.type is not None:
        if data.type == IssueType.SUBTASK:
            effective_parent = (
                data.parent_id if "parent_id" in update_dict else issue.parent_id
            )
            if effective_parent is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="A subtask must have a parent issue.",
                )
            has_children = (
                db.scalar(
                    select(func.count(Issue.id)).where(
                        Issue.parent_id == issue.id,
                        Issue.deleted_at.is_(None),
                    )
                )
                or 0
            ) > 0
            if has_children:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="An issue with child issues cannot be converted to a subtask.",
                )
        issue.type = data.type

    if "assignee_id" in update_dict:
        if data.assignee_id is not None:
            assignee = db.scalar(
                select(User).where(
                    User.id == data.assignee_id,
                    User.deleted_at.is_(None),
                )
            )
            if assignee is None or not assignee.is_active:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Assignee not found or inactive.",
                )
            if not _is_user_project_member(db, issue.project_id, data.assignee_id):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Assignee must be a member of the project.",
                )
            issue.assignee_id = data.assignee_id
        else:
            issue.assignee_id = None

    if "parent_id" in update_dict:
        if data.parent_id is not None:
            if data.parent_id == issue.id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="An issue cannot be its own parent.",
                )
            parent = db.scalar(
                select(Issue).where(
                    Issue.id == data.parent_id,
                    Issue.deleted_at.is_(None),
                )
            )
            if parent is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Parent issue not found.",
                )
            if parent.project_id != issue.project_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Parent issue must belong to the same project.",
                )
            if parent.type == IssueType.SUBTASK:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="A subtask cannot have child issues.",
                )
            _check_circular_parent(db, issue.id, data.parent_id)
            issue.parent_id = data.parent_id
        else:
            effective_type = data.type if "type" in update_dict else issue.type
            if effective_type == IssueType.SUBTASK:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="A subtask must have a parent issue.",
                )
            issue.parent_id = None

    if "sprint_id" in update_dict:
        if data.sprint_id is not None:
            sprint = db.scalar(
                select(Sprint).where(
                    Sprint.id == data.sprint_id,
                    Sprint.deleted_at.is_(None),
                )
            )
            if sprint is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Sprint not found.",
                )
            if sprint.project_id != issue.project_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Sprint must belong to the same project.",
                )
            issue.sprint_id = data.sprint_id
        else:
            issue.sprint_id = None

    if "backlog_rank" in update_dict and data.backlog_rank is not None:
        issue.backlog_rank = data.backlog_rank

    db.commit()
    db.refresh(issue)
    return get_issue_by_id(db, issue.id)


def delete_issue(db: Session, issue: Issue) -> None:
    """Soft delete an issue and all active sub-issues."""
    _soft_delete_issue_recursive(db, issue)
    db.commit()


def restore_issue(db: Session, issue_id: uuid.UUID, actor: User) -> Issue:
    """Restore a soft-deleted issue and its sub-issues."""
    issue = db.scalar(
        select(Issue)
        .options(
            selectinload(Issue.parent),
            selectinload(Issue.sub_issues),
        )
        .where(Issue.id == issue_id)
    )
    if issue is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Issue not found.",
        )

    actor_role = _resolve_effective_role(db, issue.project_id, actor.id)
    if not actor_role or not role_has_permission(actor_role, Permission.ISSUE_DELETE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to restore this issue.",
        )

    if issue.deleted_at is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Issue is not deleted.",
        )

    _restore_issue_recursive(db, issue)
    db.commit()
    return get_issue_by_id(db, issue.id)


def list_sub_issues(db: Session, issue_id: uuid.UUID) -> list[Issue]:
    """Retrieve all active sub-issues for a given parent issue."""
    get_issue_by_id(db, issue_id)
    return list(
        db.scalars(
            select(Issue)
            .options(
                selectinload(Issue.parent),
                selectinload(Issue.sub_issues),
            )
            .where(
                Issue.parent_id == issue_id,
                Issue.deleted_at.is_(None),
            )
            .order_by(Issue.issue_number.asc())
        ).all()
    )
