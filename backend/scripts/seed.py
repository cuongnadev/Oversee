"""Idempotent database seed script for Oversee.

Creates for target user (default: vincentt@mail.com):
  - 1 Workspace ("Oversee Core Workspace")
  - 1 Project ("Oversee Platform", key "OVS")
  - 2 Sprints (1 Active + 1 Planned)
  - 8 Issues per Sprint (16 Issues total)
  - 3 Teammate users added as workspace & project members so Participant Workloads
    displays realistic multi-user allocation.

Usage (from backend/):
    uv run python scripts/seed.py
    uv run python scripts/seed.py --email vincentt@mail.com
"""

from __future__ import annotations

import argparse
import os
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path

# Allow running directly via `uv run python scripts/seed.py` without installing package editable
BACKEND_SRC = Path(__file__).resolve().parents[1] / "src"
if str(BACKEND_SRC) not in sys.path:
    sys.path.insert(0, str(BACKEND_SRC))

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models.enums import (
    IssuePriority,
    IssueStatus,
    IssueType,
    RoleType,
    SprintStatus,
)
from app.models.issue import Issue
from app.models.membership import ProjectMember, WorkspaceMember
from app.models.project import Project
from app.models.sprint import Sprint
from app.models.user import User
from app.models.workspace import Workspace

DEFAULT_OWNER_EMAIL = "vincentt@mail.com"
WORKSPACE_SLUG = "oversee-core"
WORKSPACE_NAME = "Oversee Core Workspace"
PROJECT_KEY = "OVS"
PROJECT_NAME = "Oversee Platform"

TEAMMATE_SPECS = [
    ("alice.nguyen@oversee.dev", "Alice Nguyen", RoleType.ADMIN),
    ("bob.tran@oversee.dev", "Bob Tran", RoleType.MEMBER),
    ("clara.pham@oversee.dev", "Clara Pham", RoleType.MEMBER),
]


def _get_or_create_user(
    db: Session,
    *,
    email: str,
    full_name: str,
    password: str,
) -> tuple[User, bool]:
    user = db.scalar(select(User).where(User.email == email))
    if user is not None:
        if user.deleted_at is not None:
            user.deleted_at = None
        if not user.is_active:
            user.is_active = True
        return user, False

    user = User(
        email=email,
        full_name=full_name,
        hashed_password=hash_password(password),
        is_active=True,
    )
    db.add(user)
    db.flush()
    return user, True


def _ensure_workspace_member(
    db: Session,
    *,
    workspace_id,
    user_id,
    role: RoleType,
) -> None:
    existing = db.scalar(
        select(WorkspaceMember).where(
            WorkspaceMember.workspace_id == workspace_id,
            WorkspaceMember.user_id == user_id,
        )
    )
    if existing is None:
        db.add(WorkspaceMember(workspace_id=workspace_id, user_id=user_id, role=role))
    else:
        existing.role = role


def _ensure_project_member(
    db: Session,
    *,
    project_id,
    user_id,
    role: RoleType,
) -> None:
    existing = db.scalar(
        select(ProjectMember).where(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == user_id,
        )
    )
    if existing is None:
        db.add(ProjectMember(project_id=project_id, user_id=user_id, role=role))
    else:
        existing.role = role


def _get_or_create_sprint(
    db: Session,
    *,
    project_id,
    name: str,
    goal: str,
    status: SprintStatus,
    start_date: datetime,
    end_date: datetime,
    capacity: float,
) -> Sprint:
    sprint = db.scalar(
        select(Sprint).where(
            Sprint.project_id == project_id,
            Sprint.name == name,
            Sprint.deleted_at.is_(None),
        )
    )
    if sprint is not None:
        return sprint

    sprint = Sprint(
        project_id=project_id,
        name=name,
        goal=goal,
        status=status,
        start_date=start_date,
        end_date=end_date,
        capacity=capacity,
    )
    db.add(sprint)
    db.flush()
    return sprint


def _upsert_issue(
    db: Session,
    *,
    project_id,
    sprint_id,
    issue_number: int,
    title: str,
    description: str,
    issue_type: IssueType,
    status: IssueStatus,
    priority: IssuePriority,
    estimate: float,
    backlog_rank: float,
    reporter_id,
    assignee_id,
    start_date: datetime,
    end_date: datetime,
) -> tuple[Issue, bool]:
    existing = db.scalar(
        select(Issue).where(
            Issue.project_id == project_id,
            Issue.issue_number == issue_number,
        )
    )
    if existing is not None:
        return existing, False

    issue = Issue(
        project_id=project_id,
        sprint_id=sprint_id,
        issue_number=issue_number,
        title=title,
        description=description,
        type=issue_type,
        status=status,
        priority=priority,
        estimate=estimate,
        backlog_rank=backlog_rank,
        reporter_id=reporter_id,
        assignee_id=assignee_id,
        start_date=start_date,
        end_date=end_date,
    )
    db.add(issue)
    db.flush()
    return issue, True


def seed_for_user(
    db: Session,
    *,
    owner_email: str = DEFAULT_OWNER_EMAIL,
    create_owner_if_missing: bool = False,
) -> dict[str, int | str]:
    now = datetime.now(UTC).replace(hour=9, minute=0, second=0, microsecond=0)
    dev_password = os.getenv("SEED_TEAMMATE_PASSWORD", "OverseeSeed!2026")

    owner = db.scalar(select(User).where(User.email == owner_email))
    if owner is None:
        if not create_owner_if_missing:
            raise RuntimeError(
                f"Target user '{owner_email}' was not found in database. "
                "Pass --create-user to create it automatically."
            )
        owner, _ = _get_or_create_user(
            db,
            email=owner_email,
            full_name="Vincent",
            password=dev_password,
        )
    else:
        if owner.deleted_at is not None:
            owner.deleted_at = None
        if not owner.is_active:
            owner.is_active = True

    teammates: list[tuple[User, RoleType]] = []
    created_teammates = 0
    for email, full_name, role in TEAMMATE_SPECS:
        user, created = _get_or_create_user(
            db,
            email=email,
            full_name=full_name,
            password=dev_password,
        )
        if created:
            created_teammates += 1
        teammates.append((user, role))

    alice, bob, clara = teammates[0][0], teammates[1][0], teammates[2][0]

    # 1. Workspace (1 workspace)
    workspace = db.scalar(select(Workspace).where(Workspace.slug == WORKSPACE_SLUG))
    if workspace is None:
        workspace = Workspace(
            name=WORKSPACE_NAME,
            slug=WORKSPACE_SLUG,
            description="Primary Oversee engineering workspace seeded for platform development.",
            owner_id=owner.id,
        )
        db.add(workspace)
        db.flush()
    elif workspace.deleted_at is not None:
        workspace.deleted_at = None

    _ensure_workspace_member(db, workspace_id=workspace.id, user_id=owner.id, role=RoleType.OWNER)
    for mate, role in teammates:
        _ensure_workspace_member(db, workspace_id=workspace.id, user_id=mate.id, role=role)

    # 2. Project (1 project per workspace)
    project = db.scalar(
        select(Project).where(
            Project.workspace_id == workspace.id,
            Project.key == PROJECT_KEY,
        )
    )
    if project is None:
        project = Project(
            workspace_id=workspace.id,
            name=PROJECT_NAME,
            key=PROJECT_KEY,
            description="Multi-platform project management suite with sprint tracking and analytics.",
        )
        db.add(project)
        db.flush()
    elif project.deleted_at is not None:
        project.deleted_at = None

    _ensure_project_member(db, project_id=project.id, user_id=owner.id, role=RoleType.OWNER)
    for mate, role in teammates:
        _ensure_project_member(db, project_id=project.id, user_id=mate.id, role=role)

    # 3. Sprints (2 sprints per project: 1 Active + 1 Planned)
    sprint_1 = _get_or_create_sprint(
        db,
        project_id=project.id,
        name="Sprint 1: Core Platform Delivery",
        goal="Ship core workspace shell, bilingual UI, and sprint workflow foundations.",
        status=SprintStatus.ACTIVE,
        start_date=now - timedelta(days=5),
        end_date=now + timedelta(days=9),
        capacity=36.0,
    )
    sprint_2 = _get_or_create_sprint(
        db,
        project_id=project.id,
        name="Sprint 2: Insights & Optimization",
        goal="Deliver participant workload insights, calendar drag-rescheduling, and perf polish.",
        status=SprintStatus.PLANNED,
        start_date=now + timedelta(days=10),
        end_date=now + timedelta(days=24),
        capacity=32.0,
    )

    # 4. Issues (8 issues per sprint = 16 issues total)
    sprint_1_specs = [
        (
            1,
            "Implement bilingual EN/VI localization shell",
            "Add English and Vietnamese localization delegates and TopBar language switcher.",
            IssueType.STORY,
            IssueStatus.IN_PROGRESS,
            IssuePriority.HIGH,
            5.0,
            owner.id,
            now - timedelta(days=2),
            now + timedelta(days=2),
        ),
        (
            2,
            "Add dual font scaling settings (app & content pane)",
            "Support independent whole-app and content-pane font scaling in additive 10% steps.",
            IssueType.STORY,
            IssueStatus.IN_REVIEW,
            IssuePriority.HIGH,
            5.0,
            owner.id,
            now - timedelta(days=1),
            now + timedelta(days=3),
        ),
        (
            3,
            "Display resolved project name in TopBar breadcrumb",
            "Resolve project name from project provider instead of raw UUID in AppHeader.",
            IssueType.BUG,
            IssueStatus.TODO,
            IssuePriority.MEDIUM,
            2.0,
            owner.id,
            now + timedelta(days=1),
            now + timedelta(days=4),
        ),
        (
            4,
            "Configure JWT refresh token rotation & revocation",
            "Ensure refresh endpoint revokes previous jti and issues fresh token pair.",
            IssueType.TASK,
            IssueStatus.DONE,
            IssuePriority.URGENT,
            5.0,
            owner.id,
            now - timedelta(days=5),
            now - timedelta(days=2),
        ),
        (
            5,
            "Build sprint burndown daily aggregation query",
            "Compute remaining story points per sprint day for Overview burndown chart.",
            IssueType.STORY,
            IssueStatus.DONE,
            IssuePriority.HIGH,
            5.0,
            alice.id,
            now - timedelta(days=4),
            now - timedelta(days=1),
        ),
        (
            6,
            "Refine Kanban drag-and-drop column transitions",
            "Validate workflow state transitions when moving cards across columns.",
            IssueType.TASK,
            IssueStatus.IN_PROGRESS,
            IssuePriority.MEDIUM,
            5.0,
            alice.id,
            now - timedelta(days=1),
            now + timedelta(days=4),
        ),
        (
            7,
            "Optimize PostgreSQL issue filter indexes",
            "Add composite index coverage for project_id, sprint_id, and status filters.",
            IssueType.TASK,
            IssueStatus.DONE,
            IssuePriority.MEDIUM,
            3.0,
            bob.id,
            now - timedelta(days=5),
            now - timedelta(days=3),
        ),
        (
            8,
            "Standardize 150ms display/vanish popup transitions",
            "Apply uniform 150ms fade and scale transitions to dialogs, sheets, and menus.",
            IssueType.TASK,
            IssueStatus.TODO,
            IssuePriority.LOW,
            3.0,
            clara.id,
            now + timedelta(days=2),
            now + timedelta(days=6),
        ),
    ]

    sprint_2_specs = [
        (
            9,
            "Design Overview 3-column work focus cards",
            "Add My Ongoing Jobs, Upcoming Jobs, and Project Participant Workloads row.",
            IssueType.STORY,
            IssueStatus.TODO,
            IssuePriority.HIGH,
            5.0,
            owner.id,
            now + timedelta(days=10),
            now + timedelta(days=14),
        ),
        (
            10,
            "Add calendar inline date-range drag rescheduling",
            "Allow dragging issue bars on Calendar view to update start_date and end_date.",
            IssueType.STORY,
            IssueStatus.TODO,
            IssuePriority.MEDIUM,
            5.0,
            owner.id,
            now + timedelta(days=12),
            now + timedelta(days=17),
        ),
        (
            11,
            "Export project workload report to CSV",
            "Generate downloadable participant workload and story point summary.",
            IssueType.TASK,
            IssueStatus.TODO,
            IssuePriority.MEDIUM,
            3.0,
            alice.id,
            now + timedelta(days=11),
            now + timedelta(days=15),
        ),
        (
            12,
            "Implement real-time notification feed backend",
            "Track mentions, assignments, and sprint transitions for topbar bell popup.",
            IssueType.STORY,
            IssueStatus.BACKLOG,
            IssuePriority.HIGH,
            5.0,
            alice.id,
            now + timedelta(days=13),
            now + timedelta(days=19),
        ),
        (
            13,
            "Add keyboard shortcut cheat-sheet localization",
            "Localize KeyboardShortcutsDialog entries and command palette search labels.",
            IssueType.TASK,
            IssueStatus.TODO,
            IssuePriority.LOW,
            2.0,
            bob.id,
            now + timedelta(days=11),
            now + timedelta(days=14),
        ),
        (
            14,
            "Audit RBAC guards on document update endpoints",
            "Verify Viewer role receives 403 on PATCH/DELETE document operations.",
            IssueType.BUG,
            IssueStatus.TODO,
            IssuePriority.HIGH,
            3.0,
            bob.id,
            now + timedelta(days=14),
            now + timedelta(days=18),
        ),
        (
            15,
            "Add empty-state illustrations for Roadmap & Reports",
            "Create responsive light/dark empty states aligned with Oversee design tokens.",
            IssueType.TASK,
            IssueStatus.BACKLOG,
            IssuePriority.LOW,
            3.0,
            clara.id,
            now + timedelta(days=15),
            now + timedelta(days=20),
        ),
        (
            16,
            "Benchmark cold-start latency on Flutter Web",
            "Profile initial bundle load and defer non-critical chart assets.",
            IssueType.TASK,
            IssueStatus.BACKLOG,
            IssuePriority.MEDIUM,
            5.0,
            clara.id,
            now + timedelta(days=18),
            now + timedelta(days=23),
        ),
    ]

    created_issues = 0
    for rank_idx, spec in enumerate(sprint_1_specs, start=1):
        (
            issue_number,
            title,
            description,
            issue_type,
            status,
            priority,
            estimate,
            assignee_id,
            start_dt,
            end_dt,
        ) = spec
        _, created = _upsert_issue(
            db,
            project_id=project.id,
            sprint_id=sprint_1.id,
            issue_number=issue_number,
            title=title,
            description=description,
            issue_type=issue_type,
            status=status,
            priority=priority,
            estimate=estimate,
            backlog_rank=float(rank_idx * 100),
            reporter_id=owner.id,
            assignee_id=assignee_id,
            start_date=start_dt,
            end_date=end_dt,
        )
        if created:
            created_issues += 1

    for rank_idx, spec in enumerate(sprint_2_specs, start=9):
        (
            issue_number,
            title,
            description,
            issue_type,
            status,
            priority,
            estimate,
            assignee_id,
            start_dt,
            end_dt,
        ) = spec
        _, created = _upsert_issue(
            db,
            project_id=project.id,
            sprint_id=sprint_2.id,
            issue_number=issue_number,
            title=title,
            description=description,
            issue_type=issue_type,
            status=status,
            priority=priority,
            estimate=estimate,
            backlog_rank=float(rank_idx * 100),
            reporter_id=owner.id,
            assignee_id=assignee_id,
            start_date=start_dt,
            end_date=end_dt,
        )
        if created:
            created_issues += 1

    db.commit()

    sprint_1_count = len(
        db.scalars(select(Issue.id).where(Issue.sprint_id == sprint_1.id, Issue.deleted_at.is_(None))).all()
    )
    sprint_2_count = len(
        db.scalars(select(Issue.id).where(Issue.sprint_id == sprint_2.id, Issue.deleted_at.is_(None))).all()
    )

    return {
        "owner_email": owner.email,
        "workspace_slug": workspace.slug,
        "workspace_id": str(workspace.id),
        "project_key": project.key,
        "project_id": str(project.id),
        "teammates_total": len(teammates),
        "teammates_created": created_teammates,
        "sprints_total": 2,
        "sprint_1_issues": sprint_1_count,
        "sprint_2_issues": sprint_2_count,
        "issues_created_this_run": created_issues,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed Oversee database for a target user.")
    parser.add_argument(
        "--email",
        default=DEFAULT_OWNER_EMAIL,
        help=f"Target owner email (default: {DEFAULT_OWNER_EMAIL})",
    )
    parser.add_argument(
        "--create-user",
        action="store_true",
        help="Create the target owner user if not already present.",
    )
    args = parser.parse_args()

    db = SessionLocal()
    try:
        summary = seed_for_user(
            db,
            owner_email=args.email,
            create_owner_if_missing=args.create_user,
        )
        print("Seed completed successfully:")
        for key, value in summary.items():
            print(f"  {key}: {value}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
