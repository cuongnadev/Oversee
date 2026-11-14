import uuid

import pytest
from pydantic import ValidationError
from sqlalchemy import create_engine, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

from app.models.base import Base
from app.models.user import User
from app.models.workspace import Workspace
from app.schemas.workspace import (
    WorkspaceCreate,
    WorkspaceResponse,
    WorkspaceUpdate,
)


@pytest.fixture
def db_session():
    """In-memory SQLite session for testing Workspace model."""
    engine = create_engine("sqlite:///:memory:")
    # Enable SQLite foreign key constraints
    with engine.connect() as conn:
        conn.exec_driver_sql("PRAGMA foreign_keys = ON")

    Base.metadata.create_all(engine, tables=[User.__table__, Workspace.__table__])
    session_factory = sessionmaker(bind=engine)
    session = session_factory()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(engine, tables=[Workspace.__table__, User.__table__])


def test_workspace_creation_with_owner(db_session):
    """Test creating a workspace associated with an owner User."""
    owner = User(
        email="owner@example.com",
        hashed_password="hashed_password",
        full_name="Workspace Owner",
    )
    db_session.add(owner)
    db_session.commit()

    workspace = Workspace(
        name="Team 04 Workspace",
        slug="team-04",
        description="Software Project Management Team Workspace",
        owner_id=owner.id,
    )
    db_session.add(workspace)
    db_session.commit()

    # Query Workspace by ID
    saved = db_session.scalar(select(Workspace).where(Workspace.id == workspace.id))
    assert saved is not None
    assert saved.name == "Team 04 Workspace"
    assert saved.slug == "team-04"
    assert saved.description == "Software Project Management Team Workspace"
    assert saved.owner_id == owner.id

    # Verify relationship navigation: workspace -> owner
    assert saved.owner is not None
    assert saved.owner.email == "owner@example.com"
    assert saved.owner.full_name == "Workspace Owner"

    # Verify backref navigation: owner -> owned_workspaces
    assert len(owner.owned_workspaces) == 1
    assert owner.owned_workspaces[0].slug == "team-04"


def test_workspace_slug_unique_constraint(db_session):
    """Test that duplicate workspace slugs raise an IntegrityError."""
    owner = User(
        email="user_unique@example.com",
        hashed_password="hash",
        full_name="User",
    )
    db_session.add(owner)
    db_session.commit()

    ws1 = Workspace(
        name="Workspace 1",
        slug="shared-slug",
        owner_id=owner.id,
    )
    db_session.add(ws1)
    db_session.commit()

    ws2 = Workspace(
        name="Workspace 2",
        slug="shared-slug",
        owner_id=owner.id,
    )
    db_session.add(ws2)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


def test_workspace_soft_delete(db_session):
    """Test soft delete and restore lifecycle for Workspace."""
    owner = User(
        email="owner_soft@example.com",
        hashed_password="hash",
        full_name="Owner",
    )
    db_session.add(owner)
    db_session.commit()

    ws = Workspace(
        name="Temporary Workspace",
        slug="temp-ws",
        owner_id=owner.id,
    )
    db_session.add(ws)
    db_session.commit()

    assert ws.is_deleted is False
    assert ws.deleted_at is None

    ws.soft_delete()
    db_session.commit()

    assert ws.is_deleted is True
    assert ws.deleted_at is not None

    ws.restore()
    db_session.commit()

    assert ws.is_deleted is False
    assert ws.deleted_at is None


def test_workspace_pydantic_schemas():
    """Test Workspace Pydantic schema validation and serialization."""
    # Valid WorkspaceCreate
    valid_create = WorkspaceCreate(
        name="Oversee Engineering",
        slug="oversee-eng",
        description="Core dev team",
    )
    assert valid_create.slug == "oversee-eng"

    # Invalid slug (contains spaces / uppercase)
    with pytest.raises(ValidationError):
        WorkspaceCreate(
            name="Bad Slug Team",
            slug="Invalid Slug!",
        )

    # Valid WorkspaceUpdate
    valid_update = WorkspaceUpdate(name="New Team Name")
    assert valid_update.name == "New Team Name"
    assert valid_update.slug is None

    # Serialization from SQLAlchemy model to WorkspaceResponse
    dummy_owner_id = uuid.uuid4()
    ws_model = Workspace(
        name="API Project Workspace",
        slug="api-project",
        owner_id=dummy_owner_id,
    )
    response_dto = WorkspaceResponse.model_validate(ws_model)
    assert response_dto.id == ws_model.id
    assert response_dto.name == "API Project Workspace"
    assert response_dto.slug == "api-project"
    assert response_dto.owner_id == dummy_owner_id
