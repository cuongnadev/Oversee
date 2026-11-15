import uuid
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.permissions import ROLE_HIERARCHY, role_has_permission
from app.models.enums import Permission, RoleType, SprintStatus
from app.models.issue import Issue
from app.models.membership import ProjectMember, WorkspaceMember
from app.models.project import Project
from app.models.sprint import Sprint
from app.models.user import User
from app.schemas.sprint import SprintCreate, SprintPlanningResponse, SprintUpdate


def _resolve_effective_role(
    db: Session, project_id: uuid.UUID, user_id: uuid.UUID
) -> RoleType | None:
    """Resolve effective role for a user in a project, considering workspace owner/admin inheritance."""
    member = db.scalar(
        select(ProjectMember).where(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == user_id,
        )
    )
    effective_role = member.role if member else None

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
        if ws_member is not None and (
            effective_role is None
            or ROLE_HIERARCHY.get(ws_member.role, 0)
            > ROLE_HIERARCHY.get(effective_role, 0)
        ):
            effective_role = ws_member.role

    return effective_role


def create_sprint(
    db: Session,
    project_id: uuid.UUID,
    actor: User,
    data: SprintCreate,
) -> Sprint:
    """
    Create a new sprint for a project.
    Validates:
      - Actor has SPRINT_CREATE permission.
      - start_date < end_date.
      - At most one ACTIVE sprint per project.
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
    if actor_role is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found.",
        )
    if not role_has_permission(actor_role, Permission.SPRINT_CREATE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to create sprints in this project.",
        )

    # Validate dates
    if (
        data.start_date is not None
        and data.end_date is not None
        and data.start_date >= data.end_date
    ):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Sprint start_date must be strictly before end_date.",
        )

    # Validate only one active sprint per project
    if data.status == SprintStatus.ACTIVE:
        active_sprint = db.scalar(
            select(Sprint).where(
                Sprint.project_id == project_id,
                Sprint.status == SprintStatus.ACTIVE,
                Sprint.deleted_at.is_(None),
            )
        )
        if active_sprint is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"An active sprint already exists in this project ('{active_sprint.name}'). Only one active sprint is allowed at a time.",
            )

    sprint = Sprint(
        project_id=project_id,
        name=data.name,
        goal=data.goal,
        start_date=data.start_date,
        end_date=data.end_date,
        capacity=data.capacity,
        status=data.status,
    )
    db.add(sprint)
    db.commit()
    db.refresh(sprint)
    return sprint


def get_sprint_by_id(db: Session, sprint_id: uuid.UUID) -> Sprint:
    """Retrieve an active sprint by ID."""
    sprint = db.scalar(
        select(Sprint).where(
            Sprint.id == sprint_id,
            Sprint.deleted_at.is_(None),
        )
    )
    if sprint is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sprint not found.",
        )
    return sprint


def list_project_sprints(
    db: Session,
    project_id: uuid.UUID,
    status_filter: SprintStatus | None = None,
) -> list[Sprint]:
    """Retrieve all non-deleted sprints for a project, optionally filtered by status."""
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
        Sprint.project_id == project_id,
        Sprint.deleted_at.is_(None),
    ]
    if status_filter is not None:
        conditions.append(Sprint.status == status_filter)

    return list(
        db.scalars(
            select(Sprint).where(*conditions).order_by(Sprint.created_at.desc())
        ).all()
    )


def update_sprint(
    db: Session,
    sprint: Sprint,
    actor: User,
    data: SprintUpdate,
) -> Sprint:
    """
    Update a sprint's attributes.
    Validates:
      - Actor has SPRINT_UPDATE permission.
      - start_date < end_date.
      - At most one ACTIVE sprint per project.
    """
    actor_role = _resolve_effective_role(db, sprint.project_id, actor.id)
    if not actor_role or not role_has_permission(actor_role, Permission.SPRINT_UPDATE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to update this sprint.",
        )

    update_dict = data.model_dump(exclude_unset=True)

    # Validate dates across existing and updated values
    effective_start = (
        data.start_date if "start_date" in update_dict else sprint.start_date
    )
    effective_end = data.end_date if "end_date" in update_dict else sprint.end_date
    if (
        effective_start is not None
        and effective_end is not None
        and effective_start >= effective_end
    ):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Sprint start_date must be strictly before end_date.",
        )

    # Validate only one active sprint per project
    if (
        "status" in update_dict
        and data.status == SprintStatus.ACTIVE
        and sprint.status != SprintStatus.ACTIVE
    ):
        active_sprint = db.scalar(
            select(Sprint).where(
                Sprint.project_id == sprint.project_id,
                Sprint.id != sprint.id,
                Sprint.status == SprintStatus.ACTIVE,
                Sprint.deleted_at.is_(None),
            )
        )
        if active_sprint is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"An active sprint already exists in this project ('{active_sprint.name}'). Only one active sprint is allowed at a time.",
            )

    for field, value in update_dict.items():
        setattr(sprint, field, value)

    db.commit()
    db.refresh(sprint)
    return sprint


def delete_sprint(
    db: Session,
    sprint: Sprint,
    actor: User,
) -> None:
    """
    Soft delete a sprint.
    Issues belonging to this sprint are moved back to the product backlog (sprint_id = None).
    Requires SPRINT_DELETE permission (ADMIN or higher).
    """
    actor_role = _resolve_effective_role(db, sprint.project_id, actor.id)
    if not actor_role or not role_has_permission(actor_role, Permission.SPRINT_DELETE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to delete this sprint.",
        )

    # Return any assigned issues to backlog
    issues = list(
        db.scalars(
            select(Issue).where(
                Issue.sprint_id == sprint.id,
                Issue.deleted_at.is_(None),
            )
        ).all()
    )
    for issue in issues:
        issue.sprint_id = None

    sprint.soft_delete()
    db.commit()


# ---------------------------------------------------------------------------
# Sprint Planning & Issue Assignment (#101)
# ---------------------------------------------------------------------------
def add_issues_to_sprint(
    db: Session,
    sprint: Sprint,
    actor: User,
    issue_ids: list[uuid.UUID],
) -> list[Issue]:
    """
    Assign a list of issues to the specified sprint.
    Enforces:
      - Actor has SPRINT_UPDATE permission.
      - Each issue exists and belongs to the same project as the sprint.
      - Each issue is assigned to at most one sprint (sprint_id updated).
    """
    actor_role = _resolve_effective_role(db, sprint.project_id, actor.id)
    if not actor_role or not role_has_permission(actor_role, Permission.SPRINT_UPDATE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to assign issues to this sprint.",
        )

    assigned: list[Issue] = []
    for issue_id in issue_ids:
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
                detail=f"Issue '{issue_id}' not found.",
            )
        if issue.project_id != sprint.project_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Issue '{issue_id}' does not belong to the sprint's project.",
            )
        issue.sprint_id = sprint.id
        assigned.append(issue)

    db.commit()
    for issue in assigned:
        db.refresh(issue)
    return assigned


def remove_issue_from_sprint(
    db: Session,
    sprint: Sprint,
    actor: User,
    issue_id: uuid.UUID,
) -> Issue:
    """
    Remove an issue from a sprint, returning it to the product backlog (sprint_id = None).
    """
    actor_role = _resolve_effective_role(db, sprint.project_id, actor.id)
    if not actor_role or not role_has_permission(actor_role, Permission.SPRINT_UPDATE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to remove issues from this sprint.",
        )

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
    if issue.sprint_id != sprint.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Issue is not assigned to this sprint.",
        )

    issue.sprint_id = None
    db.commit()
    db.refresh(issue)
    return issue


def remove_issues_from_sprint(
    db: Session,
    sprint: Sprint,
    actor: User,
    issue_ids: list[uuid.UUID],
) -> list[Issue]:
    """
    Batch remove issues from a sprint, returning them to the product backlog.
    """
    actor_role = _resolve_effective_role(db, sprint.project_id, actor.id)
    if not actor_role or not role_has_permission(actor_role, Permission.SPRINT_UPDATE):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to remove issues from this sprint.",
        )

    removed: list[Issue] = []
    for issue_id in issue_ids:
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
        if issue is not None and issue.sprint_id == sprint.id:
            issue.sprint_id = None
            removed.append(issue)

    db.commit()
    for issue in removed:
        db.refresh(issue)
    return removed


def list_sprint_issues(
    db: Session,
    sprint: Sprint,
) -> list[Issue]:
    """
    Retrieve all non-deleted issues assigned to this sprint.
    """
    return list(
        db.scalars(
            select(Issue)
            .options(
                selectinload(Issue.parent),
                selectinload(Issue.sub_issues),
            )
            .where(
                Issue.sprint_id == sprint.id,
                Issue.deleted_at.is_(None),
            )
            .order_by(Issue.issue_number.asc())
        ).all()
    )


def get_sprint_planning(
    db: Session,
    sprint: Sprint,
) -> SprintPlanningResponse:
    """
    Generate sprint planning summary including assigned issues, total estimate,
    capacity limit, and capacity warning.
    """
    issues = list_sprint_issues(db, sprint)
    total_issues = len(issues)
    total_estimate = sum(issue.estimate or 0.0 for issue in issues)
    capacity = sprint.capacity
    is_over_capacity = capacity is not None and total_estimate > capacity
    warning = (
        f"Sprint estimate ({total_estimate}) exceeds planned capacity ({capacity})."
        if is_over_capacity
        else None
    )

    return SprintPlanningResponse(
        sprint=sprint,
        issues=issues,
        total_issues=total_issues,
        total_estimate=total_estimate,
        capacity=capacity,
        is_over_capacity=is_over_capacity,
        warning=warning,
    )
