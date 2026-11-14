import uuid

import pytest
from pydantic import ValidationError
from sqlalchemy import create_engine, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

from app.models.base import Base
from app.models.enums import IssuePriority, IssueStatus, IssueType
from app.models.issue import Issue
from app.models.project import Project
from app.models.user import User
from app.models.workspace import Workspace
from app.schemas.issue import (
    IssueCreate,
    IssueResponse,
    IssueUpdate,
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
    """Seed user reporter, assignee, workspace, and project."""
    reporter = User(
        email="reporter@example.com",
        hashed_password="hash",
        full_name="Issue Reporter",
    )
    assignee = User(
        email="assignee@example.com",
        hashed_password="hash",
        full_name="Assigned Developer",
    )
    db_session.add_all([reporter, assignee])
    db_session.commit()

    workspace = Workspace(
        name="Issue Tracking Org",
        slug="issue-org",
        owner_id=reporter.id,
    )
    db_session.add(workspace)
    db_session.commit()

    project = Project(
        name="Sprint Tracker",
        key="TRK",
        workspace_id=workspace.id,
    )
    db_session.add(project)
    db_session.commit()

    return {
        "reporter": reporter,
        "assignee": assignee,
        "workspace": workspace,
        "project": project,
    }


def test_issue_creation_with_assignee_and_parent(db_session, base_data):
    """
    Test creating an issue with assignee and parent issue hierarchy.
    Fulfills the acceptance criteria for Issue #54.
    """
    reporter = base_data["reporter"]
    assignee = base_data["assignee"]
    project = base_data["project"]

    # 1. Create Parent Issue (Epic/Story)
    parent_issue = Issue(
        project_id=project.id,
        issue_number=1,
        title="Epic: User Authentication",
        description="Comprehensive authentication system",
        type=IssueType.EPIC,
        status=IssueStatus.IN_PROGRESS,
        priority=IssuePriority.HIGH,
        reporter_id=reporter.id,
    )
    db_session.add(parent_issue)
    db_session.commit()

    # 2. Create Child Issue (Task) linked to Parent and assigned to developer
    child_issue = Issue(
        project_id=project.id,
        issue_number=2,
        title="Task: Implement Login Endpoint",
        description="FastAPI endpoint for OAuth2 password flow",
        type=IssueType.TASK,
        status=IssueStatus.TODO,
        priority=IssuePriority.HIGH,
        reporter_id=reporter.id,
        assignee_id=assignee.id,
        parent_id=parent_issue.id,
    )
    db_session.add(child_issue)
    db_session.commit()

    # Query and verify child issue
    saved_child = db_session.scalar(select(Issue).where(Issue.id == child_issue.id))
    assert saved_child is not None
    assert saved_child.title == "Task: Implement Login Endpoint"
    assert saved_child.issue_number == 2
    assert saved_child.type == IssueType.TASK
    assert saved_child.status == IssueStatus.TODO
    assert saved_child.priority == IssuePriority.HIGH

    # Verify relationships
    assert saved_child.assignee is not None
    assert saved_child.assignee.email == "assignee@example.com"
    assert saved_child.reporter.email == "reporter@example.com"
    assert saved_child.parent is not None
    assert saved_child.parent.id == parent_issue.id
    assert saved_child.parent.title == "Epic: User Authentication"

    # Verify parent collection
    assert len(parent_issue.sub_issues) == 1
    assert parent_issue.sub_issues[0].id == child_issue.id


def test_issue_number_unique_within_same_project(db_session, base_data):
    """Verify that duplicate issue_numbers within the same project raise IntegrityError."""
    reporter = base_data["reporter"]
    project = base_data["project"]

    i1 = Issue(
        project_id=project.id,
        issue_number=10,
        title="First Issue #10",
        reporter_id=reporter.id,
    )
    db_session.add(i1)
    db_session.commit()

    i2 = Issue(
        project_id=project.id,
        issue_number=10,
        title="Duplicate Issue #10",
        reporter_id=reporter.id,
    )
    db_session.add(i2)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


def test_issue_number_allowed_in_different_projects(db_session, base_data):
    """Verify that the same issue_number can exist in different projects."""
    reporter = base_data["reporter"]
    workspace = base_data["workspace"]
    p1 = base_data["project"]

    p2 = Project(
        name="Second Project",
        key="SEC",
        workspace_id=workspace.id,
    )
    db_session.add(p2)
    db_session.commit()

    i1 = Issue(
        project_id=p1.id,
        issue_number=1,
        title="Issue 1 in Project 1",
        reporter_id=reporter.id,
    )
    i2 = Issue(
        project_id=p2.id,
        issue_number=1,
        title="Issue 1 in Project 2",
        reporter_id=reporter.id,
    )
    db_session.add_all([i1, i2])
    db_session.commit()

    assert i1.issue_number == i2.issue_number == 1
    assert i1.project_id != i2.project_id


def test_parent_child_cascade_delete(db_session, base_data):
    """Verify deleting a parent issue cascades and deletes its sub_issues."""
    reporter = base_data["reporter"]
    project = base_data["project"]

    parent = Issue(
        project_id=project.id,
        issue_number=100,
        title="Parent to be deleted",
        reporter_id=reporter.id,
    )
    db_session.add(parent)
    db_session.commit()

    child = Issue(
        project_id=project.id,
        issue_number=101,
        title="Child to be cascaded",
        reporter_id=reporter.id,
        parent_id=parent.id,
    )
    db_session.add(child)
    db_session.commit()

    child_id = child.id
    db_session.delete(parent)
    db_session.commit()

    # Sub-issue should be deleted
    assert db_session.scalar(select(Issue).where(Issue.id == child_id)) is None


def test_issue_soft_delete(db_session, base_data):
    """Test soft delete and restore on an issue."""
    reporter = base_data["reporter"]
    project = base_data["project"]

    issue = Issue(
        project_id=project.id,
        issue_number=200,
        title="Soft Delete Issue",
        reporter_id=reporter.id,
    )
    db_session.add(issue)
    db_session.commit()

    assert issue.is_deleted is False
    assert issue.deleted_at is None

    issue.soft_delete()
    db_session.commit()

    assert issue.is_deleted is True
    assert issue.deleted_at is not None

    issue.restore()
    db_session.commit()

    assert issue.is_deleted is False
    assert issue.deleted_at is None


def test_issue_pydantic_schemas():
    """Test Pydantic schemas for Issue."""
    dummy_project_id = uuid.uuid4()
    dummy_reporter_id = uuid.uuid4()
    dummy_assignee_id = uuid.uuid4()
    dummy_parent_id = uuid.uuid4()

    # Valid IssueCreate
    valid_create = IssueCreate(
        project_id=dummy_project_id,
        issue_number=1,
        title="Write Integration Tests",
        type=IssueType.TASK,
        status=IssueStatus.TODO,
        priority=IssuePriority.HIGH,
        assignee_id=dummy_assignee_id,
        parent_id=dummy_parent_id,
    )
    assert valid_create.issue_number == 1
    assert valid_create.priority == IssuePriority.HIGH

    # Invalid issue_number (< 1)
    with pytest.raises(ValidationError):
        IssueCreate(
            project_id=dummy_project_id,
            issue_number=0,
            title="Invalid Number Issue",
        )

    # Valid IssueUpdate
    valid_update = IssueUpdate(status=IssueStatus.DONE, priority=IssuePriority.URGENT)
    assert valid_update.status == IssueStatus.DONE
    assert valid_update.priority == IssuePriority.URGENT
    assert valid_update.title is None

    # Serialization from SQLAlchemy model to IssueResponse
    issue_model = Issue(
        project_id=dummy_project_id,
        issue_number=42,
        title="Serialized Issue",
        type=IssueType.BUG,
        status=IssueStatus.IN_REVIEW,
        priority=IssuePriority.URGENT,
        reporter_id=dummy_reporter_id,
    )
    response_dto = IssueResponse.model_validate(issue_model)
    assert response_dto.id == issue_model.id
    assert response_dto.issue_number == 42
    assert response_dto.type == IssueType.BUG
    assert response_dto.status == IssueStatus.IN_REVIEW
    assert response_dto.reporter_id == dummy_reporter_id
