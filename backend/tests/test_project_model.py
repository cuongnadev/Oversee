import uuid

import pytest
from pydantic import ValidationError
from sqlalchemy import create_engine, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

from app.models.base import Base
from app.models.project import Project
from app.models.user import User
from app.models.workspace import Workspace
from app.schemas.project import (
    ProjectCreate,
    ProjectResponse,
    ProjectUpdate,
)


@pytest.fixture
def db_session():
    """In-memory SQLite session for testing Project model."""
    engine = create_engine("sqlite:///:memory:")
    with engine.connect() as conn:
        conn.exec_driver_sql("PRAGMA foreign_keys = ON")

    Base.metadata.create_all(
        engine, tables=[User.__table__, Workspace.__table__, Project.__table__]
    )
    session_factory = sessionmaker(bind=engine)
    session = session_factory()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(
            engine,
            tables=[Project.__table__, Workspace.__table__, User.__table__],
        )


@pytest.fixture
def test_workspace(db_session):
    """Fixture providing a persisted Workspace with owner User."""
    owner = User(
        email="owner_project_test@example.com",
        hashed_password="hash",
        full_name="Project Test Owner",
    )
    db_session.add(owner)
    db_session.commit()

    workspace = Workspace(
        name="Engineering Workspace",
        slug="eng-ws",
        owner_id=owner.id,
    )
    db_session.add(workspace)
    db_session.commit()
    return workspace


def test_project_creation_and_relationship(db_session, test_workspace):
    """Test creating a project belonging to a workspace."""
    project = Project(
        name="Oversee Core Backend",
        key="OVS",
        description="FastAPI service for Oversee",
        workspace_id=test_workspace.id,
    )
    db_session.add(project)
    db_session.commit()

    saved = db_session.scalar(select(Project).where(Project.id == project.id))
    assert saved is not None
    assert saved.name == "Oversee Core Backend"
    assert saved.key == "OVS"
    assert saved.description == "FastAPI service for Oversee"
    assert saved.workspace_id == test_workspace.id

    # Verify forward relationship: project -> workspace
    assert saved.workspace is not None
    assert saved.workspace.slug == "eng-ws"

    # Verify backward relationship: workspace -> projects
    assert len(test_workspace.projects) == 1
    assert test_workspace.projects[0].key == "OVS"


def test_project_key_unique_within_same_workspace(db_session, test_workspace):
    """Test that two projects in the same workspace cannot share the same key."""
    p1 = Project(
        name="Project Alpha",
        key="ALP",
        workspace_id=test_workspace.id,
    )
    db_session.add(p1)
    db_session.commit()

    p2 = Project(
        name="Project Another Alpha",
        key="ALP",
        workspace_id=test_workspace.id,
    )
    db_session.add(p2)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


def test_project_key_allowed_in_different_workspaces(db_session, test_workspace):
    """Test that the same project key is allowed in different workspaces."""
    # Create second workspace
    ws2 = Workspace(
        name="Marketing Workspace",
        slug="marketing-ws",
        owner_id=test_workspace.owner_id,
    )
    db_session.add(ws2)
    db_session.commit()

    p1 = Project(
        name="Alpha In Eng",
        key="ALPHA",
        workspace_id=test_workspace.id,
    )
    p2 = Project(
        name="Alpha In Marketing",
        key="ALPHA",
        workspace_id=ws2.id,
    )
    db_session.add_all([p1, p2])
    db_session.commit()

    assert p1.key == p2.key == "ALPHA"
    assert p1.workspace_id != p2.workspace_id


def test_project_soft_delete(db_session, test_workspace):
    """Test soft delete and restore lifecycle for Project."""
    project = Project(
        name="Deprecated Project",
        key="DEP",
        workspace_id=test_workspace.id,
    )
    db_session.add(project)
    db_session.commit()

    assert project.is_deleted is False
    assert project.deleted_at is None

    project.soft_delete()
    db_session.commit()

    assert project.is_deleted is True
    assert project.deleted_at is not None

    project.restore()
    db_session.commit()

    assert project.is_deleted is False
    assert project.deleted_at is None


def test_project_pydantic_schemas():
    """Test Project Pydantic schema validation and serialization."""
    dummy_ws_id = uuid.uuid4()

    # Valid ProjectCreate
    valid_create = ProjectCreate(
        name="Mobile App",
        key="MOB1",
        workspace_id=dummy_ws_id,
        description="iOS and Android app",
    )
    assert valid_create.key == "MOB1"

    # Invalid key (lowercase letters not allowed by regex ^[A-Z0-9]+$)
    with pytest.raises(ValidationError):
        ProjectCreate(
            name="Mobile App",
            key="mob",
            workspace_id=dummy_ws_id,
        )

    # Invalid key (special characters not allowed)
    with pytest.raises(ValidationError):
        ProjectCreate(
            name="Mobile App",
            key="MOB-1",
            workspace_id=dummy_ws_id,
        )

    # Valid ProjectUpdate
    valid_update = ProjectUpdate(name="Updated Mobile App")
    assert valid_update.name == "Updated Mobile App"
    assert valid_update.description is None

    # Serialization from SQLAlchemy model
    p_model = Project(
        name="Frontend Dashboard",
        key="FE",
        workspace_id=dummy_ws_id,
    )
    response_dto = ProjectResponse.model_validate(p_model)
    assert response_dto.id == p_model.id
    assert response_dto.name == "Frontend Dashboard"
    assert response_dto.key == "FE"
    assert response_dto.workspace_id == dummy_ws_id
