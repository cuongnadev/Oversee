import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

from app.models.base import Base
from app.models.enums import RoleType
from app.models.membership import ProjectMember, WorkspaceMember
from app.models.project import Project
from app.models.user import User
from app.models.workspace import Workspace
from app.schemas.membership import (
    ProjectMemberCreate,
    ProjectMemberResponse,
    WorkspaceMemberCreate,
    WorkspaceMemberResponse,
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
        WorkspaceMember.__table__,
        Project.__table__,
        ProjectMember.__table__,
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
    """Seed owner, member user, workspace, and project."""
    owner = User(
        email="owner_mem@example.com",
        hashed_password="hash",
        full_name="Workspace Owner",
    )
    user = User(
        email="developer_mem@example.com",
        hashed_password="hash",
        full_name="Software Developer",
    )
    db_session.add_all([owner, user])
    db_session.commit()

    workspace = Workspace(
        name="Engineering Org",
        slug="eng-org",
        owner_id=owner.id,
    )
    db_session.add(workspace)
    db_session.commit()

    project = Project(
        name="Platform API",
        key="PLAT",
        workspace_id=workspace.id,
    )
    db_session.add(project)
    db_session.commit()

    return {
        "owner": owner,
        "user": user,
        "workspace": workspace,
        "project": project,
    }


def test_workspace_member_creation_and_navigation(db_session, base_data):
    """Test creating a workspace member and navigating relationships."""
    user = base_data["user"]
    workspace = base_data["workspace"]

    wm = WorkspaceMember(
        workspace_id=workspace.id,
        user_id=user.id,
        role=RoleType.ADMIN,
    )
    db_session.add(wm)
    db_session.commit()

    saved = db_session.scalar(
        select(WorkspaceMember).where(WorkspaceMember.id == wm.id)
    )
    assert saved is not None
    assert saved.role == RoleType.ADMIN
    assert saved.workspace.slug == "eng-org"
    assert saved.user.email == "developer_mem@example.com"

    # Verify backref collections
    assert len(workspace.members) == 1
    assert len(user.workspace_memberships) == 1


def test_project_member_creation_and_navigation(db_session, base_data):
    """Test creating a project member and navigating relationships."""
    user = base_data["user"]
    project = base_data["project"]

    pm = ProjectMember(
        project_id=project.id,
        user_id=user.id,
        role=RoleType.MEMBER,
    )
    db_session.add(pm)
    db_session.commit()

    saved = db_session.scalar(select(ProjectMember).where(ProjectMember.id == pm.id))
    assert saved is not None
    assert saved.role == RoleType.MEMBER
    assert saved.project.key == "PLAT"
    assert saved.user.email == "developer_mem@example.com"

    # Verify backref collections
    assert len(project.members) == 1
    assert len(user.project_memberships) == 1


def test_cannot_add_same_user_twice_to_workspace(db_session, base_data):
    """Verify unique constraint uq_workspace_members_user prevents duplicate memberships."""
    user = base_data["user"]
    workspace = base_data["workspace"]

    wm1 = WorkspaceMember(
        workspace_id=workspace.id,
        user_id=user.id,
        role=RoleType.MEMBER,
    )
    db_session.add(wm1)
    db_session.commit()

    wm2 = WorkspaceMember(
        workspace_id=workspace.id,
        user_id=user.id,
        role=RoleType.ADMIN,
    )
    db_session.add(wm2)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


def test_cannot_add_same_user_twice_to_project(db_session, base_data):
    """Verify unique constraint uq_project_members_user prevents duplicate project memberships."""
    user = base_data["user"]
    project = base_data["project"]

    pm1 = ProjectMember(
        project_id=project.id,
        user_id=user.id,
        role=RoleType.VIEWER,
    )
    db_session.add(pm1)
    db_session.commit()

    pm2 = ProjectMember(
        project_id=project.id,
        user_id=user.id,
        role=RoleType.MEMBER,
    )
    db_session.add(pm2)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


def test_same_user_allowed_in_different_workspaces(db_session, base_data):
    """Test that the same user can belong to multiple distinct workspaces."""
    user = base_data["user"]
    owner = base_data["owner"]
    ws1 = base_data["workspace"]

    ws2 = Workspace(
        name="Design Studio",
        slug="design-studio",
        owner_id=owner.id,
    )
    db_session.add(ws2)
    db_session.commit()

    wm1 = WorkspaceMember(
        workspace_id=ws1.id,
        user_id=user.id,
        role=RoleType.MEMBER,
    )
    wm2 = WorkspaceMember(
        workspace_id=ws2.id,
        user_id=user.id,
        role=RoleType.OWNER,
    )
    db_session.add_all([wm1, wm2])
    db_session.commit()

    assert len(user.workspace_memberships) == 2


def test_cascade_delete_memberships(db_session, base_data):
    """Test that deleting a workspace or project cascades to member records."""
    workspace = base_data["workspace"]
    project = base_data["project"]
    user = base_data["user"]

    wm = WorkspaceMember(
        workspace_id=workspace.id,
        user_id=user.id,
        role=RoleType.MEMBER,
    )
    pm = ProjectMember(
        project_id=project.id,
        user_id=user.id,
        role=RoleType.MEMBER,
    )
    db_session.add_all([wm, pm])
    db_session.commit()

    wm_id = wm.id

    # Delete workspace (which also cascades to project in PostgreSQL/SQLite)
    db_session.delete(workspace)
    db_session.commit()

    assert (
        db_session.scalar(select(WorkspaceMember).where(WorkspaceMember.id == wm_id))
        is None
    )


def test_membership_pydantic_schemas(base_data):
    """Test Pydantic schemas for workspace and project members."""
    user = base_data["user"]
    workspace = base_data["workspace"]
    project = base_data["project"]

    # Workspace member DTO
    ws_create = WorkspaceMemberCreate(user_id=user.id, role=RoleType.ADMIN)
    assert ws_create.role == RoleType.ADMIN

    wm_model = WorkspaceMember(
        workspace_id=workspace.id,
        user_id=user.id,
        role=RoleType.ADMIN,
    )
    ws_resp = WorkspaceMemberResponse.model_validate(wm_model)
    assert ws_resp.id == wm_model.id
    assert ws_resp.role == RoleType.ADMIN
    assert ws_resp.workspace_id == workspace.id

    # Project member DTO
    p_create = ProjectMemberCreate(user_id=user.id, role=RoleType.VIEWER)
    assert p_create.role == RoleType.VIEWER

    pm_model = ProjectMember(
        project_id=project.id,
        user_id=user.id,
        role=RoleType.VIEWER,
    )
    p_resp = ProjectMemberResponse.model_validate(pm_model)
    assert p_resp.id == pm_model.id
    assert p_resp.role == RoleType.VIEWER
    assert p_resp.project_id == project.id
