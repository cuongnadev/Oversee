import uuid
from datetime import UTC, datetime, timedelta

import pytest
from pydantic import ValidationError
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker

from app.models.base import Base
from app.models.enums import IssuePriority, IssueStatus, IssueType, SprintStatus
from app.models.issue import Issue
from app.models.project import Project
from app.models.sprint import Sprint
from app.models.user import User
from app.models.workspace import Workspace
from app.schemas.sprint import (
    SprintCreate,
    SprintResponse,
    SprintUpdate,
)


@pytest.fixture
def db_session():
    """In-memory SQLite session with foreign keys enabled."""
    engine = create_engine("sqlite:///:memory:")
    with engine.connect() as conn:
        conn.exec_driver_sql("PRAGMA foreign_keys = ON")

    tables = [
        User.__table__,
        Workspace.__table__,
        Project.__table__,
        Sprint.__table__,
        Issue.__table__,
    ]
    Base.metadata.create_all(engine, tables=tables)
    session_factory = sessionmaker(bind=engine)
    session = session_factory()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(engine, tables=tables)


@pytest.fixture
def base_data(db_session):
    """Seed user, workspace, and project."""
    user = User(
        email="scrum_master@example.com",
        hashed_password="hash",
        full_name="Scrum Master",
    )
    db_session.add(user)
    db_session.commit()

    workspace = Workspace(
        name="Agile Team Org",
        slug="agile-org",
        owner_id=user.id,
    )
    db_session.add(workspace)
    db_session.commit()

    project = Project(
        name="Oversee Sprint App",
        key="APP",
        workspace_id=workspace.id,
    )
    db_session.add(project)
    db_session.commit()

    return {"user": user, "workspace": workspace, "project": project}


def test_sprint_creation_and_relationship(db_session, base_data):
    """Test creating a sprint linked to a project."""
    project = base_data["project"]
    now = datetime.now(UTC)

    sprint = Sprint(
        project_id=project.id,
        name="Sprint 1 - Foundation",
        goal="Set up database models and core APIs",
        start_date=now,
        end_date=now + timedelta(days=14),
        status=SprintStatus.ACTIVE,
    )
    db_session.add(sprint)
    db_session.commit()

    saved = db_session.scalar(select(Sprint).where(Sprint.id == sprint.id))
    assert saved is not None
    assert saved.name == "Sprint 1 - Foundation"
    assert saved.status == SprintStatus.ACTIVE
    assert saved.project.key == "APP"

    # Verify backref from project
    assert len(project.sprints) == 1
    assert project.sprints[0].id == sprint.id


def test_issue_backlog_criteria(db_session, base_data):
    """
    Test acceptance criteria:
    Issue belongs to backlog when not assigned to any sprint (sprint_id is None).
    """
    user = base_data["user"]
    project = base_data["project"]

    # 1. Create issue without sprint
    backlog_issue = Issue(
        project_id=project.id,
        issue_number=1,
        title="Unassigned Backlog Item",
        type=IssueType.TASK,
        status=IssueStatus.BACKLOG,
        priority=IssuePriority.MEDIUM,
        reporter_id=user.id,
        sprint_id=None,
        backlog_rank=10.0,
    )
    db_session.add(backlog_issue)
    db_session.commit()

    # Verify backlog criteria
    assert backlog_issue.is_backlog is True
    assert backlog_issue.sprint is None

    # 2. Create sprint and assign issue to sprint
    sprint = Sprint(
        project_id=project.id,
        name="Sprint 2",
        status=SprintStatus.PLANNED,
    )
    db_session.add(sprint)
    db_session.commit()

    backlog_issue.sprint_id = sprint.id
    db_session.commit()

    # Now the issue is part of the sprint and no longer backlog
    assert backlog_issue.is_backlog is False
    assert backlog_issue.sprint is not None
    assert backlog_issue.sprint.name == "Sprint 2"
    assert len(sprint.issues) == 1
    assert sprint.issues[0].id == backlog_issue.id

    # 3. Remove issue from sprint -> returns to backlog
    backlog_issue.sprint_id = None
    db_session.commit()

    assert backlog_issue.is_backlog is True
    assert len(sprint.issues) == 0


def test_backlog_ranking_order(db_session, base_data):
    """Test backlog priority ordering by backlog_rank field."""
    user = base_data["user"]
    project = base_data["project"]

    i1 = Issue(
        project_id=project.id,
        issue_number=1,
        title="Third Priority Item",
        reporter_id=user.id,
        backlog_rank=30.0,
    )
    i2 = Issue(
        project_id=project.id,
        issue_number=2,
        title="First Priority Item",
        reporter_id=user.id,
        backlog_rank=10.0,
    )
    i3 = Issue(
        project_id=project.id,
        issue_number=3,
        title="Second Priority Item",
        reporter_id=user.id,
        backlog_rank=20.0,
    )
    db_session.add_all([i1, i2, i3])
    db_session.commit()

    # Query backlog ordered by rank
    backlog_items = db_session.scalars(
        select(Issue)
        .where(
            Issue.project_id == project.id,
            Issue.sprint_id.is_(None),
        )
        .order_by(Issue.backlog_rank.asc())
    ).all()

    assert len(backlog_items) == 3
    assert backlog_items[0].title == "First Priority Item"
    assert backlog_items[1].title == "Second Priority Item"
    assert backlog_items[2].title == "Third Priority Item"


def test_sprint_deletion_sets_null_cascade(db_session, base_data):
    """Test that deleting a sprint resets issue.sprint_id to NULL (ON DELETE SET NULL)."""
    user = base_data["user"]
    project = base_data["project"]

    sprint = Sprint(
        project_id=project.id,
        name="Sprint to Delete",
        status=SprintStatus.PLANNED,
    )
    db_session.add(sprint)
    db_session.commit()

    issue = Issue(
        project_id=project.id,
        issue_number=5,
        title="Sprint Task",
        reporter_id=user.id,
        sprint_id=sprint.id,
    )
    db_session.add(issue)
    db_session.commit()

    assert issue.is_backlog is False

    # Delete sprint
    db_session.delete(sprint)
    db_session.commit()

    # Issue must return to backlog
    db_session.refresh(issue)
    assert issue.sprint_id is None
    assert issue.is_backlog is True


def test_sprint_soft_delete(db_session, base_data):
    """Test soft delete and restore lifecycle for Sprint."""
    project = base_data["project"]

    sprint = Sprint(
        project_id=project.id,
        name="Temporary Sprint",
    )
    db_session.add(sprint)
    db_session.commit()

    assert sprint.is_deleted is False
    assert sprint.deleted_at is None

    sprint.soft_delete()
    db_session.commit()

    assert sprint.is_deleted is True
    assert sprint.deleted_at is not None

    sprint.restore()
    db_session.commit()

    assert sprint.is_deleted is False
    assert sprint.deleted_at is None


def test_sprint_pydantic_schemas():
    """Test Sprint Pydantic schema validation and serialization."""
    dummy_project_id = uuid.uuid4()

    # Valid SprintCreate
    valid_create = SprintCreate(
        name="Sprint 1",
        goal="MVP release",
        project_id=dummy_project_id,
        status=SprintStatus.PLANNED,
    )
    assert valid_create.name == "Sprint 1"
    assert valid_create.status == SprintStatus.PLANNED

    # Invalid empty name
    with pytest.raises(ValidationError):
        SprintCreate(
            name="",
            project_id=dummy_project_id,
        )

    # Valid SprintUpdate
    valid_update = SprintUpdate(status=SprintStatus.ACTIVE)
    assert valid_update.status == SprintStatus.ACTIVE
    assert valid_update.name is None

    # Serialization from SQLAlchemy model to SprintResponse
    sprint_model = Sprint(
        name="Sprint Model Test",
        project_id=dummy_project_id,
        status=SprintStatus.COMPLETED,
    )
    response_dto = SprintResponse.model_validate(sprint_model)
    assert response_dto.id == sprint_model.id
    assert response_dto.name == "Sprint Model Test"
    assert response_dto.status == SprintStatus.COMPLETED
