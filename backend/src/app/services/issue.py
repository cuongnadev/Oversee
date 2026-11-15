import base64
import json
import logging
import math
import uuid
from typing import Any, Final

from fastapi import HTTPException, status
from sqlalchemy import case, func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.permissions import ROLE_HIERARCHY, role_has_permission
from app.models.activity import Activity
from app.models.enums import (
    IssuePriority,
    IssueStatus,
    IssueType,
    Permission,
    RoleType,
)
from app.models.issue import Issue
from app.models.membership import ProjectMember, WorkspaceMember
from app.models.project import Project
from app.models.sprint import Sprint
from app.models.user import User
from app.schemas.issue import IssueCreate, IssuePageResponse, IssueUpdate

logger = logging.getLogger("oversee.activity")

VALID_STATUS_TRANSITIONS: Final[dict[IssueStatus, set[IssueStatus]]] = {
    IssueStatus.BACKLOG: {
        IssueStatus.BACKLOG,
        IssueStatus.TODO,
        IssueStatus.CANCELED,
    },
    IssueStatus.TODO: {
        IssueStatus.TODO,
        IssueStatus.BACKLOG,
        IssueStatus.IN_PROGRESS,
        IssueStatus.CANCELED,
    },
    IssueStatus.IN_PROGRESS: {
        IssueStatus.IN_PROGRESS,
        IssueStatus.TODO,
        IssueStatus.IN_REVIEW,
        IssueStatus.CANCELED,
    },
    IssueStatus.IN_REVIEW: {
        IssueStatus.IN_REVIEW,
        IssueStatus.IN_PROGRESS,
        IssueStatus.DONE,
        IssueStatus.CANCELED,
    },
    IssueStatus.DONE: {
        IssueStatus.DONE,
        IssueStatus.IN_PROGRESS,
        IssueStatus.TODO,
        IssueStatus.BACKLOG,
        IssueStatus.CANCELED,
    },
    IssueStatus.CANCELED: {
        IssueStatus.CANCELED,
        IssueStatus.BACKLOG,
        IssueStatus.TODO,
    },
}


def validate_status_transition(
    current_status: IssueStatus, target_status: IssueStatus
) -> None:
    """
    Validate that transition from current_status to target_status is permitted.

    :raises HTTPException: 422 Unprocessable Content if transition is invalid.
    """
    allowed = VALID_STATUS_TRANSITIONS.get(current_status, set())
    if target_status not in allowed:
        allowed_names = sorted(s.value for s in allowed if s != current_status)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=(
                f"Invalid status transition from '{current_status.value}' to '{target_status.value}'. "
                f"Allowed transitions: {allowed_names}."
            ),
        )


_activity_log: list[Activity] = []


def log_activity(
    issue_id: uuid.UUID,
    actor_id: uuid.UUID,
    action: str,
    old_value: Any = None,
    new_value: Any = None,
    db: Session | None = None,
) -> Activity:
    """
    Log an activity event for an issue and persist it in the activity history.

    :param issue_id: UUID of the affected issue.
    :param actor_id: UUID of the user making the change.
    :param action: Action descriptor (e.g. 'assignee_changed', 'priority_changed', 'status_changed').
    :param old_value: Previous value before change.
    :param new_value: Updated value after change.
    :param db: Optional active database session to persist Activity to database.
    :return: The created Activity entity.
    """
    old_str = str(old_value) if old_value is not None else None
    new_str = str(new_value) if new_value is not None else None
    record = Activity(
        issue_id=issue_id,
        actor_id=actor_id,
        action=action,
        old_value=old_str,
        new_value=new_str,
    )
    if db is not None:
        db.add(record)
        db.flush()
    _activity_log.append(record)
    logger.info(
        "Activity [issue=%s]: %s changed from %s to %s by user %s",
        issue_id,
        action,
        old_str,
        new_str,
        actor_id,
    )
    return record


def get_issue_activities(
    issue_id: uuid.UUID,
    db: Session | None = None,
) -> list[Activity]:
    """Retrieve all recorded activity log records for a given issue."""
    target_id = (
        issue_id if isinstance(issue_id, uuid.UUID) else uuid.UUID(str(issue_id))
    )
    if db is not None:
        db_records = list(
            db.scalars(
                select(Activity)
                .where(Activity.issue_id == target_id)
                .order_by(Activity.created_at.asc())
            ).all()
        )
        if db_records:
            return db_records
    return [r for r in _activity_log if r.issue_id == target_id]


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
        estimate=data.estimate,
        backlog_rank=data.backlog_rank if data.backlog_rank is not None else 0.0,
    )
    db.add(new_issue)
    db.commit()
    db.refresh(new_issue)

    log_activity(
        issue_id=new_issue.id,
        actor_id=actor.id,
        action="issue_created",
        old_value=None,
        new_value=new_issue.title,
        db=db,
    )
    db.commit()

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


def parse_issue_statuses(
    status_param: list[str] | str | None,
) -> list[IssueStatus] | None:
    """Parse status query parameter into a validated list of IssueStatus enums."""
    if not status_param:
        return None
    raw_list = status_param if isinstance(status_param, list) else [status_param]
    result: list[IssueStatus] = []
    for item in raw_list:
        for part in item.split(","):
            part = part.strip()
            if not part:
                continue
            try:
                result.append(IssueStatus(part))
            except ValueError:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail=f"Invalid issue status: '{part}'",
                )
    return result if result else None


def parse_issue_priorities(
    priority_param: list[str] | str | None,
) -> list[IssuePriority] | None:
    """Parse priority query parameter into a validated list of IssuePriority enums."""
    if not priority_param:
        return None
    raw_list = priority_param if isinstance(priority_param, list) else [priority_param]
    result: list[IssuePriority] = []
    for item in raw_list:
        for part in item.split(","):
            part = part.strip()
            if not part:
                continue
            try:
                result.append(IssuePriority(part))
            except ValueError:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail=f"Invalid issue priority: '{part}'",
                )
    return result if result else None


def _build_sort_clauses(
    sort: str | None = None,
    sort_by: str | None = None,
    order: str = "asc",
) -> list[Any]:
    """
    Build SQLAlchemy order_by clauses from sort expressions or sort_by/order.
    Supports comma-separated multi-field sorting, e.g.:
      - 'priority:desc,created_at:asc'
      - '-priority,created_at'
    """
    priority_order = case(
        (Issue.priority == IssuePriority.LOWEST, 1),
        (Issue.priority == IssuePriority.LOW, 2),
        (Issue.priority == IssuePriority.MEDIUM, 3),
        (Issue.priority == IssuePriority.HIGH, 4),
        (Issue.priority == IssuePriority.URGENT, 5),
        else_=0,
    )

    status_order = case(
        (Issue.status == IssueStatus.BACKLOG, 1),
        (Issue.status == IssueStatus.TODO, 2),
        (Issue.status == IssueStatus.IN_PROGRESS, 3),
        (Issue.status == IssueStatus.IN_REVIEW, 4),
        (Issue.status == IssueStatus.DONE, 5),
        (Issue.status == IssueStatus.CANCELED, 6),
        else_=0,
    )

    field_map: dict[str, Any] = {
        "issue_number": Issue.issue_number,
        "number": Issue.issue_number,
        "title": Issue.title,
        "status": status_order,
        "priority": priority_order,
        "created_at": Issue.created_at,
        "updated_at": Issue.updated_at,
        "backlog_rank": Issue.backlog_rank,
        "rank": Issue.backlog_rank,
    }

    clauses: list[Any] = []

    if sort:
        tokens = [t.strip() for t in sort.split(",") if t.strip()]
        for token in tokens:
            direction = "asc"
            field_name = token
            if field_name.startswith("-"):
                direction = "desc"
                field_name = field_name[1:]
            elif field_name.startswith("+"):
                direction = "asc"
                field_name = field_name[1:]
            elif ":" in field_name:
                parts = field_name.split(":", 1)
                field_name = parts[0].strip()
                direction = parts[1].strip().lower()

            if direction not in ("asc", "desc"):
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail=f"Invalid sort direction '{direction}'. Must be 'asc' or 'desc'.",
                )

            col = field_map.get(field_name.lower())
            if col is None:
                allowed = ", ".join(sorted(field_map.keys()))
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail=f"Invalid sort field: '{field_name}'. Allowed fields: {allowed}",
                )

            clauses.append(col.desc() if direction == "desc" else col.asc())

    elif sort_by:
        field_name = sort_by.strip().lower()
        col = field_map.get(field_name)
        if col is None:
            allowed = ", ".join(sorted(field_map.keys()))
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=f"Invalid sort field: '{sort_by}'. Allowed fields: {allowed}",
            )
        direction = order.strip().lower()
        if direction not in ("asc", "desc"):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=f"Invalid sort direction '{order}'. Must be 'asc' or 'desc'.",
            )
        clauses.append(col.desc() if direction == "desc" else col.asc())

    if not clauses:
        clauses.append(Issue.issue_number.asc())
    else:
        clauses.append(Issue.id.asc())

    return clauses


def list_project_issues(
    db: Session,
    project_id: uuid.UUID,
    page: int = 1,
    page_size: int = 20,
    statuses: list[IssueStatus] | None = None,
    assignee_id: uuid.UUID | None = None,
    assignee: str | None = None,
    priorities: list[IssuePriority] | None = None,
    sprint_id: uuid.UUID | None = None,
    sprint: str | None = None,
    issue_type: IssueType | None = None,
    parent_id: uuid.UUID | None = None,
    search: str | None = None,
    sort: str | None = None,
    sort_by: str | None = None,
    order: str = "asc",
    cursor: str | None = None,
) -> IssuePageResponse:
    """List non-deleted issues for a project with filtering, multi-field sorting, and pagination."""
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

    conditions: list[Any] = [
        Issue.project_id == project_id,
        Issue.deleted_at.is_(None),
    ]

    # Status filter
    if statuses:
        conditions.append(Issue.status.in_(statuses))

    # Assignee filter
    if assignee is not None:
        if assignee.lower() in ("unassigned", "none", "null"):
            conditions.append(Issue.assignee_id.is_(None))
        else:
            try:
                parsed_assignee_id = uuid.UUID(assignee)
                conditions.append(Issue.assignee_id == parsed_assignee_id)
            except ValueError:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail=f"Invalid assignee ID: '{assignee}'",
                )
    elif assignee_id is not None:
        conditions.append(Issue.assignee_id == assignee_id)

    # Priority filter
    if priorities:
        conditions.append(Issue.priority.in_(priorities))

    # Sprint filter
    if sprint is not None:
        if sprint.lower() in ("none", "backlog", "null"):
            conditions.append(Issue.sprint_id.is_(None))
        else:
            try:
                parsed_sprint_id = uuid.UUID(sprint)
                conditions.append(Issue.sprint_id == parsed_sprint_id)
            except ValueError:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                    detail=f"Invalid sprint ID: '{sprint}'",
                )
    elif sprint_id is not None:
        conditions.append(Issue.sprint_id == sprint_id)

    # Issue type filter
    if issue_type is not None:
        conditions.append(Issue.type == issue_type)

    # Parent ID filter
    if parent_id is not None:
        conditions.append(Issue.parent_id == parent_id)

    # Search keyword filter
    if search and search.strip():
        term = f"%{search.strip()}%"
        conditions.append(
            or_(
                Issue.title.ilike(term),
                Issue.description.ilike(term),
            )
        )

    # Total matching count
    total = db.scalar(select(func.count(Issue.id)).where(*conditions)) or 0

    # Pagination calculation (cursor vs offset)
    if cursor:
        try:
            raw = base64.urlsafe_b64decode(cursor.encode()).decode()
            cursor_data = json.loads(raw)
            offset = int(cursor_data["offset"])
            if offset < 0:
                raise ValueError
        except (
            ValueError,
            KeyError,
            TypeError,
            json.JSONDecodeError,
            UnicodeDecodeError,
        ):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Invalid pagination cursor.",
            )
        page = (offset // page_size) + 1
    else:
        offset = (page - 1) * page_size

    sort_clauses = _build_sort_clauses(sort=sort, sort_by=sort_by, order=order)

    items = list(
        db.scalars(
            select(Issue)
            .options(
                selectinload(Issue.parent),
                selectinload(Issue.sub_issues),
            )
            .where(*conditions)
            .order_by(*sort_clauses)
            .offset(offset)
            .limit(page_size)
        ).all()
    )

    total_pages = math.ceil(total / page_size) if total > 0 else 1
    has_more = (offset + len(items)) < total
    next_cursor = None
    if has_more:
        next_payload = {"offset": offset + len(items)}
        next_cursor = base64.urlsafe_b64encode(
            json.dumps(next_payload).encode()
        ).decode()

    return IssuePageResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
        next_cursor=next_cursor,
        has_more=has_more,
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

    old_assignee = issue.assignee_id
    old_priority = issue.priority
    old_status = issue.status
    old_title = issue.title
    old_description = issue.description
    old_sprint = issue.sprint_id

    update_dict = data.model_dump(exclude_unset=True)

    if "title" in update_dict:
        issue.title = data.title

    if "description" in update_dict:
        issue.description = data.description

    if (
        "status" in update_dict
        and data.status is not None
        and old_status != data.status
    ):
        validate_status_transition(old_status, data.status)
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

    if "estimate" in update_dict:
        issue.estimate = data.estimate

    if "backlog_rank" in update_dict and data.backlog_rank is not None:
        issue.backlog_rank = data.backlog_rank

    db.commit()
    db.refresh(issue)

    if old_status != issue.status:
        log_activity(
            issue_id=issue.id,
            actor_id=actor.id,
            action="status_changed",
            old_value=old_status.value if hasattr(old_status, "value") else old_status,
            new_value=issue.status.value
            if hasattr(issue.status, "value")
            else issue.status,
            db=db,
        )

    if old_assignee != issue.assignee_id:
        log_activity(
            issue_id=issue.id,
            actor_id=actor.id,
            action="assignee_changed",
            old_value=old_assignee,
            new_value=issue.assignee_id,
            db=db,
        )

    if old_priority != issue.priority:
        log_activity(
            issue_id=issue.id,
            actor_id=actor.id,
            action="priority_changed",
            old_value=old_priority.value
            if hasattr(old_priority, "value")
            else old_priority,
            new_value=issue.priority.value
            if hasattr(issue.priority, "value")
            else issue.priority,
            db=db,
        )

    if old_title != issue.title:
        log_activity(
            issue_id=issue.id,
            actor_id=actor.id,
            action="title_changed",
            old_value=old_title,
            new_value=issue.title,
            db=db,
        )

    if old_description != issue.description:
        log_activity(
            issue_id=issue.id,
            actor_id=actor.id,
            action="description_changed",
            old_value=old_description,
            new_value=issue.description,
            db=db,
        )

    if old_sprint != issue.sprint_id:
        log_activity(
            issue_id=issue.id,
            actor_id=actor.id,
            action="sprint_changed",
            old_value=old_sprint,
            new_value=issue.sprint_id,
            db=db,
        )

    db.commit()

    return get_issue_by_id(db, issue.id)


def assign_issue(
    db: Session,
    issue: Issue,
    actor: User,
    assignee_id: uuid.UUID | None,
) -> Issue:
    """
    Assign an issue to a project member or unassign it.

    :param db: Active database session.
    :param issue: The target Issue.
    :param actor: Authenticated user initiating assignment.
    :param assignee_id: Target assignee UUID, or None to unassign.
    :return: Updated Issue entity with relations loaded.
    :raises HTTPException: 400 if user not active or not in project, 403 on permission denial.
    """
    actor_role = _resolve_effective_role(db, issue.project_id, actor.id)
    if not actor_role or not role_has_permission(actor_role, Permission.ISSUE_UPDATE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to assign this issue.",
        )

    old_assignee = issue.assignee_id

    if assignee_id is not None:
        assignee = db.scalar(
            select(User).where(
                User.id == assignee_id,
                User.deleted_at.is_(None),
            )
        )
        if assignee is None or not assignee.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Assignee not found or inactive.",
            )
        if not _is_user_project_member(db, issue.project_id, assignee_id):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Assignee must be a member of the project.",
            )
        issue.assignee_id = assignee_id
    else:
        issue.assignee_id = None

    db.commit()
    db.refresh(issue)

    if old_assignee != issue.assignee_id:
        log_activity(
            issue_id=issue.id,
            actor_id=actor.id,
            action="assignee_changed",
            old_value=old_assignee,
            new_value=issue.assignee_id,
            db=db,
        )
        db.commit()

    return get_issue_by_id(db, issue.id)


def change_issue_priority(
    db: Session,
    issue: Issue,
    actor: User,
    priority: IssuePriority,
) -> Issue:
    """
    Change the priority of an issue.

    :param db: Active database session.
    :param issue: The target Issue.
    :param actor: Authenticated user initiating priority change.
    :param priority: New IssuePriority enum value.
    :return: Updated Issue entity with relations loaded.
    :raises HTTPException: 403 on permission denial.
    """
    actor_role = _resolve_effective_role(db, issue.project_id, actor.id)
    if not actor_role or not role_has_permission(actor_role, Permission.ISSUE_UPDATE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to change issue priority.",
        )

    old_priority = issue.priority
    issue.priority = priority
    db.commit()
    db.refresh(issue)

    if old_priority != issue.priority:
        log_activity(
            issue_id=issue.id,
            actor_id=actor.id,
            action="priority_changed",
            old_value=old_priority.value
            if hasattr(old_priority, "value")
            else old_priority,
            new_value=issue.priority.value
            if hasattr(issue.priority, "value")
            else issue.priority,
            db=db,
        )
        db.commit()

    return get_issue_by_id(db, issue.id)


def change_issue_status(
    db: Session,
    issue: Issue,
    actor: User,
    new_status: IssueStatus,
) -> Issue:
    """
    Transition an issue to a new status following valid workflow transition rules.

    :param db: Active database session.
    :param issue: The target Issue entity.
    :param actor: Authenticated user initiating status change.
    :param new_status: Target IssueStatus.
    :return: Updated Issue entity with relations loaded.
    :raises HTTPException: 403 on permission denial, 422 on invalid transition rule.
    """
    actor_role = _resolve_effective_role(db, issue.project_id, actor.id)
    if not actor_role or not role_has_permission(actor_role, Permission.ISSUE_UPDATE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to update issue status.",
        )

    old_status = issue.status
    if old_status != new_status:
        validate_status_transition(old_status, new_status)
        issue.status = new_status
        db.commit()
        db.refresh(issue)

        log_activity(
            issue_id=issue.id,
            actor_id=actor.id,
            action="status_changed",
            old_value=old_status.value if hasattr(old_status, "value") else old_status,
            new_value=issue.status.value
            if hasattr(issue.status, "value")
            else issue.status,
            db=db,
        )
        db.commit()

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


# ---------------------------------------------------------------------------
# Product Backlog Management (#98)
# ---------------------------------------------------------------------------
def list_backlog_issues(
    db: Session,
    project_id: uuid.UUID,
    page: int = 1,
    page_size: int = 20,
    statuses: list[IssueStatus] | None = None,
    assignee_id: uuid.UUID | None = None,
    assignee: str | None = None,
    priorities: list[IssuePriority] | None = None,
    issue_type: IssueType | None = None,
    parent_id: uuid.UUID | None = None,
    search: str | None = None,
    sort: str | None = None,
    sort_by: str | None = None,
    order: str = "asc",
    cursor: str | None = None,
) -> IssuePageResponse:
    """
    List all active issues belonging to the product backlog (sprint_id is None).
    Defaults ordering to backlog_rank:asc, issue_number:asc.
    """
    effective_sort = sort
    if not effective_sort and not sort_by:
        effective_sort = "backlog_rank:asc,issue_number:asc"

    return list_project_issues(
        db=db,
        project_id=project_id,
        page=page,
        page_size=page_size,
        statuses=statuses,
        assignee_id=assignee_id,
        assignee=assignee,
        priorities=priorities,
        sprint="backlog",
        issue_type=issue_type,
        parent_id=parent_id,
        search=search,
        sort=effective_sort,
        sort_by=sort_by,
        order=order,
        cursor=cursor,
    )


def add_issues_to_backlog(
    db: Session,
    project_id: uuid.UUID,
    actor: User,
    issue_ids: list[uuid.UUID],
) -> list[Issue]:
    """
    Add/move issues into the product backlog by setting sprint_id = None.
    Recalculates backlog_rank to place moved issues at the end of the backlog.
    Requires ISSUE_UPDATE permission.
    """
    actor_role = _resolve_effective_role(db, project_id, actor.id)
    if not actor_role or not role_has_permission(actor_role, Permission.ISSUE_UPDATE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to update issues in this project.",
        )

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

    updated_issues: list[Issue] = []
    for issue_id in issue_ids:
        issue = db.scalar(
            select(Issue)
            .options(
                selectinload(Issue.parent),
                selectinload(Issue.sub_issues),
            )
            .where(
                Issue.id == issue_id,
                Issue.project_id == project_id,
                Issue.deleted_at.is_(None),
            )
        )
        if issue is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Issue {issue_id} not found in this project.",
            )

        if issue.sprint_id is not None:
            old_sprint = str(issue.sprint_id)
            issue.sprint_id = None
            max_rank = (
                db.scalar(
                    select(func.coalesce(func.max(Issue.backlog_rank), 0.0)).where(
                        Issue.project_id == project_id,
                        Issue.sprint_id.is_(None),
                        Issue.deleted_at.is_(None),
                    )
                )
                or 0.0
            )
            issue.backlog_rank = max_rank + 10.0
            log_activity(
                issue_id=issue.id,
                actor_id=actor.id,
                action="moved_to_backlog",
                old_value=old_sprint,
                new_value="backlog",
            )
        updated_issues.append(issue)

    db.commit()
    for issue in updated_issues:
        db.refresh(issue)
    return updated_issues


def move_issue_to_backlog(
    db: Session,
    issue: Issue,
    actor: User,
) -> Issue:
    """Move a single issue into the product backlog."""
    results = add_issues_to_backlog(
        db=db,
        project_id=issue.project_id,
        actor=actor,
        issue_ids=[issue.id],
    )
    return results[0]


def remove_issue_from_backlog(
    db: Session,
    project_id: uuid.UUID,
    issue_id: uuid.UUID,
    actor: User,
    target_sprint_id: uuid.UUID | None = None,
) -> Issue | None:
    """
    Remove an issue from the backlog:
    - If target_sprint_id is provided, moves it to that sprint (requires ISSUE_UPDATE).
    - If target_sprint_id is None, soft-deletes the issue from backlog (requires ISSUE_DELETE).
    """
    issue = db.scalar(
        select(Issue)
        .options(
            selectinload(Issue.parent),
            selectinload(Issue.sub_issues),
        )
        .where(
            Issue.id == issue_id,
            Issue.project_id == project_id,
            Issue.deleted_at.is_(None),
        )
    )
    if issue is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Issue {issue_id} not found in this project.",
        )

    if issue.sprint_id is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Issue {issue_id} is not currently in the backlog.",
        )

    actor_role = _resolve_effective_role(db, project_id, actor.id)

    if target_sprint_id is not None:
        if not actor_role or not role_has_permission(
            actor_role, Permission.ISSUE_UPDATE
        ):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions to assign issue to sprint.",
            )
        sprint = db.scalar(
            select(Sprint).where(
                Sprint.id == target_sprint_id,
                Sprint.project_id == project_id,
                Sprint.deleted_at.is_(None),
            )
        )
        if sprint is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Target sprint not found in this project.",
            )
        issue.sprint_id = target_sprint_id
        log_activity(
            issue_id=issue.id,
            actor_id=actor.id,
            action="assigned_to_sprint",
            old_value="backlog",
            new_value=str(target_sprint_id),
        )
        db.commit()
        db.refresh(issue)
        return issue

    if not actor_role or not role_has_permission(actor_role, Permission.ISSUE_DELETE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to delete issue from backlog.",
        )

    _soft_delete_issue_recursive(db, issue)
    log_activity(
        issue_id=issue.id,
        actor_id=actor.id,
        action="deleted_from_backlog",
        old_value="active",
        new_value="deleted",
    )
    db.commit()
    return None


def _rebalance_backlog_ranks(db: Session, project_id: uuid.UUID) -> None:
    """Rebalance all backlog ranks to spaced intervals (10.0, 20.0, 30.0...) to prevent floating point exhaustion."""
    backlog_issues = list(
        db.scalars(
            select(Issue)
            .where(
                Issue.project_id == project_id,
                Issue.sprint_id.is_(None),
                Issue.deleted_at.is_(None),
            )
            .order_by(
                Issue.backlog_rank.asc(), Issue.issue_number.asc(), Issue.id.asc()
            )
        ).all()
    )
    for idx, item in enumerate(backlog_issues):
        item.backlog_rank = float((idx + 1) * 10)
    db.flush()


def reorder_backlog_issue(
    db: Session,
    project_id: uuid.UUID,
    issue_id: uuid.UUID,
    actor: User,
    previous_issue_id: uuid.UUID | None = None,
    next_issue_id: uuid.UUID | None = None,
    target_rank: float | None = None,
    position: str | None = None,
) -> Issue:
    """
    Reorder an issue within the product backlog.
    Computes a fractional rank value between previous_issue and next_issue,
    or places at top/bottom, guaranteeing deterministic and persistent ordering.
    Requires ISSUE_UPDATE permission.
    """
    actor_role = _resolve_effective_role(db, project_id, actor.id)
    if not actor_role or not role_has_permission(actor_role, Permission.ISSUE_UPDATE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to reorder backlog issues.",
        )

    issue = db.scalar(
        select(Issue)
        .options(
            selectinload(Issue.parent),
            selectinload(Issue.sub_issues),
        )
        .where(
            Issue.id == issue_id,
            Issue.project_id == project_id,
            Issue.deleted_at.is_(None),
        )
    )
    if issue is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Issue {issue_id} not found in this project.",
        )

    if issue.sprint_id is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only issues in the product backlog can be reordered.",
        )

    if previous_issue_id == issue_id or next_issue_id == issue_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot position an issue relative to itself.",
        )

    prev_issue: Issue | None = None
    next_issue: Issue | None = None

    if previous_issue_id is not None:
        prev_issue = db.scalar(
            select(Issue).where(
                Issue.id == previous_issue_id,
                Issue.project_id == project_id,
                Issue.sprint_id.is_(None),
                Issue.deleted_at.is_(None),
            )
        )
        if prev_issue is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Previous issue {previous_issue_id} not found in the backlog.",
            )

    if next_issue_id is not None:
        next_issue = db.scalar(
            select(Issue).where(
                Issue.id == next_issue_id,
                Issue.project_id == project_id,
                Issue.sprint_id.is_(None),
                Issue.deleted_at.is_(None),
            )
        )
        if next_issue is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Next issue {next_issue_id} not found in the backlog.",
            )

    # Calculate new_rank
    new_rank: float
    if target_rank is not None:
        new_rank = target_rank
    elif position == "top":
        min_rank = db.scalar(
            select(func.min(Issue.backlog_rank)).where(
                Issue.project_id == project_id,
                Issue.sprint_id.is_(None),
                Issue.deleted_at.is_(None),
                Issue.id != issue_id,
            )
        )
        new_rank = (min_rank - 10.0) if min_rank is not None else 10.0
    elif position == "bottom":
        max_rank = db.scalar(
            select(func.max(Issue.backlog_rank)).where(
                Issue.project_id == project_id,
                Issue.sprint_id.is_(None),
                Issue.deleted_at.is_(None),
                Issue.id != issue_id,
            )
        )
        new_rank = (max_rank + 10.0) if max_rank is not None else 10.0
    elif prev_issue is not None and next_issue is not None:
        if abs(next_issue.backlog_rank - prev_issue.backlog_rank) < 1e-6:
            _rebalance_backlog_ranks(db, project_id)
            db.refresh(prev_issue)
            db.refresh(next_issue)
        new_rank = (prev_issue.backlog_rank + next_issue.backlog_rank) / 2.0
    elif prev_issue is not None and next_issue is None:
        next_after_prev = db.scalar(
            select(Issue)
            .where(
                Issue.project_id == project_id,
                Issue.sprint_id.is_(None),
                Issue.deleted_at.is_(None),
                Issue.id != issue_id,
                Issue.backlog_rank > prev_issue.backlog_rank,
            )
            .order_by(Issue.backlog_rank.asc())
            .limit(1)
        )
        if next_after_prev is not None:
            if abs(next_after_prev.backlog_rank - prev_issue.backlog_rank) < 1e-6:
                _rebalance_backlog_ranks(db, project_id)
                db.refresh(prev_issue)
                db.refresh(next_after_prev)
            new_rank = (prev_issue.backlog_rank + next_after_prev.backlog_rank) / 2.0
        else:
            new_rank = prev_issue.backlog_rank + 10.0
    elif next_issue is not None and prev_issue is None:
        prev_before_next = db.scalar(
            select(Issue)
            .where(
                Issue.project_id == project_id,
                Issue.sprint_id.is_(None),
                Issue.deleted_at.is_(None),
                Issue.id != issue_id,
                Issue.backlog_rank < next_issue.backlog_rank,
            )
            .order_by(Issue.backlog_rank.desc())
            .limit(1)
        )
        if prev_before_next is not None:
            if abs(next_issue.backlog_rank - prev_before_next.backlog_rank) < 1e-6:
                _rebalance_backlog_ranks(db, project_id)
                db.refresh(next_issue)
                db.refresh(prev_before_next)
            new_rank = (prev_before_next.backlog_rank + next_issue.backlog_rank) / 2.0
        else:
            new_rank = next_issue.backlog_rank - 10.0
    else:
        max_rank = db.scalar(
            select(func.max(Issue.backlog_rank)).where(
                Issue.project_id == project_id,
                Issue.sprint_id.is_(None),
                Issue.deleted_at.is_(None),
                Issue.id != issue_id,
            )
        )
        new_rank = (max_rank + 10.0) if max_rank is not None else 10.0

    old_rank = issue.backlog_rank
    issue.backlog_rank = new_rank

    log_activity(
        issue_id=issue.id,
        actor_id=actor.id,
        action="backlog_reordered",
        old_value=str(old_rank),
        new_value=str(new_rank),
    )

    db.commit()
    db.refresh(issue)
    return issue
