import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.core.security import create_access_token, hash_password
from app.db.session import get_db
from app.main import app
from app.models.enums import RoleType
from app.models.membership import ProjectMember, WorkspaceMember
from app.models.project import Project
from app.models.user import User
from app.models.workspace import Workspace


# ---------------------------------------------------------------------------
# Helpers & Fixtures
# ---------------------------------------------------------------------------
def _create_user(db_session, email="user@example.com", full_name="Test User") -> User:
    user = User(
        email=email.lower().strip(),
        hashed_password=hash_password("Password123!"),
        full_name=full_name,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def _auth_header(user: User) -> dict[str, str]:
    token = create_access_token(subject=str(user.id))
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def client(db_session):
    app.dependency_overrides[get_db] = lambda: db_session
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def setup_project_data(db_session):
    ws_owner = _create_user(db_session, "ws_owner@example.com", "Workspace Owner")
    proj_owner = _create_user(db_session, "proj_owner@example.com", "Project Owner")
    proj_admin = _create_user(db_session, "proj_admin@example.com", "Project Admin")
    proj_member = _create_user(db_session, "proj_member@example.com", "Project Member")
    proj_viewer = _create_user(db_session, "proj_viewer@example.com", "Project Viewer")
    ws_member_only = _create_user(db_session, "ws_only@example.com", "Workspace Only")
    outsider = _create_user(db_session, "outsider@example.com", "Total Outsider")

    ws = Workspace(name="Alpha Workspace", slug="alpha-ws", owner_id=ws_owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.refresh(ws)

    # Add all users except outsider to Workspace
    for u, r in [
        (ws_owner, RoleType.OWNER),
        (proj_owner, RoleType.MEMBER),
        (proj_admin, RoleType.MEMBER),
        (proj_member, RoleType.MEMBER),
        (proj_viewer, RoleType.VIEWER),
        (ws_member_only, RoleType.MEMBER),
    ]:
        db_session.add(WorkspaceMember(workspace_id=ws.id, user_id=u.id, role=r))
    db_session.commit()

    # Create project
    proj = Project(name="Phoenix Project", key="PHX", workspace_id=ws.id)
    db_session.add(proj)
    db_session.commit()
    db_session.refresh(proj)

    # Add project members
    db_session.add_all(
        [
            ProjectMember(
                project_id=proj.id, user_id=proj_owner.id, role=RoleType.OWNER
            ),
            ProjectMember(
                project_id=proj.id, user_id=proj_admin.id, role=RoleType.ADMIN
            ),
            ProjectMember(
                project_id=proj.id, user_id=proj_member.id, role=RoleType.MEMBER
            ),
            ProjectMember(
                project_id=proj.id, user_id=proj_viewer.id, role=RoleType.VIEWER
            ),
        ]
    )
    db_session.commit()

    return {
        "ws_owner": ws_owner,
        "proj_owner": proj_owner,
        "proj_admin": proj_admin,
        "proj_member": proj_member,
        "proj_viewer": proj_viewer,
        "ws_member_only": ws_member_only,
        "outsider": outsider,
        "workspace": ws,
        "project": proj,
    }


# ---------------------------------------------------------------------------
# 1. GET /api/v1/projects/{project_id}/members (List Members)
# ---------------------------------------------------------------------------
def test_list_project_members_success(client, setup_project_data):
    """Project viewer can list all members with user details."""
    proj = setup_project_data["project"]
    proj_viewer = setup_project_data["proj_viewer"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/members",
        headers=_auth_header(proj_viewer),
    )
    assert resp.status_code == 200
    members = resp.json()
    assert len(members) == 4
    emails = [m["user"]["email"] for m in members if m.get("user")]
    assert "proj_owner@example.com" in emails
    assert "proj_admin@example.com" in emails


def test_list_project_members_outsider_404(client, setup_project_data):
    """User outside project and workspace receives 404."""
    proj = setup_project_data["project"]
    outsider = setup_project_data["outsider"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/members",
        headers=_auth_header(outsider),
    )
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# 2. POST /api/v1/projects/{project_id}/members (Add Member)
# ---------------------------------------------------------------------------
def test_add_project_member_by_user_id_success(client, setup_project_data):
    """Project Admin adds an existing workspace member by user_id."""
    proj = setup_project_data["project"]
    proj_admin = setup_project_data["proj_admin"]
    ws_member_only = setup_project_data["ws_member_only"]

    resp = client.post(
        f"/api/v1/projects/{proj.id}/members",
        headers=_auth_header(proj_admin),
        json={"user_id": str(ws_member_only.id), "role": "member"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["role"] == "member"
    assert data["user_id"] == str(ws_member_only.id)
    assert data["user"]["email"] == "ws_only@example.com"


def test_add_project_member_by_email_success(client, db_session, setup_project_data):
    """Project Admin adds an existing workspace member by email."""
    proj = setup_project_data["project"]
    proj_admin = setup_project_data["proj_admin"]
    ws = setup_project_data["workspace"]

    # Add new user to workspace first
    new_user = _create_user(db_session, "another_ws@example.com", "Another WS User")
    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=new_user.id, role=RoleType.MEMBER)
    )
    db_session.commit()

    resp = client.post(
        f"/api/v1/projects/{proj.id}/members",
        headers=_auth_header(proj_admin),
        json={"email": "another_ws@example.com", "role": "viewer"},
    )
    assert resp.status_code == 201
    assert resp.json()["role"] == "viewer"
    assert resp.json()["user_id"] == str(new_user.id)


def test_add_project_member_non_workspace_user_rejected(client, setup_project_data):
    """Chỉ thêm được user đã thuộc workspace (returns 400 Bad Request)."""
    proj = setup_project_data["project"]
    proj_admin = setup_project_data["proj_admin"]
    outsider = setup_project_data["outsider"]

    resp = client.post(
        f"/api/v1/projects/{proj.id}/members",
        headers=_auth_header(proj_admin),
        json={"user_id": str(outsider.id), "role": "member"},
    )
    assert resp.status_code == 400
    assert "User must be a member of the workspace" in resp.json()["detail"]


def test_add_project_member_already_member_conflict(client, setup_project_data):
    """Adding a user already in the project returns 409 Conflict."""
    proj = setup_project_data["project"]
    proj_admin = setup_project_data["proj_admin"]
    proj_member = setup_project_data["proj_member"]

    resp = client.post(
        f"/api/v1/projects/{proj.id}/members",
        headers=_auth_header(proj_admin),
        json={"user_id": str(proj_member.id), "role": "member"},
    )
    assert resp.status_code == 409
    assert "already a member" in resp.json()["detail"]


def test_admin_cannot_add_owner_role(client, setup_project_data):
    """Project Admin cannot assign the OWNER role (403)."""
    proj = setup_project_data["project"]
    proj_admin = setup_project_data["proj_admin"]
    ws_member_only = setup_project_data["ws_member_only"]

    resp = client.post(
        f"/api/v1/projects/{proj.id}/members",
        headers=_auth_header(proj_admin),
        json={"user_id": str(ws_member_only.id), "role": "owner"},
    )
    assert resp.status_code == 403
    assert "Only project owners" in resp.json()["detail"]


def test_owner_can_add_owner_role(client, setup_project_data):
    """Project Owner can assign the OWNER role to a member."""
    proj = setup_project_data["project"]
    proj_owner = setup_project_data["proj_owner"]
    ws_member_only = setup_project_data["ws_member_only"]

    resp = client.post(
        f"/api/v1/projects/{proj.id}/members",
        headers=_auth_header(proj_owner),
        json={"user_id": str(ws_member_only.id), "role": "owner"},
    )
    assert resp.status_code == 201
    assert resp.json()["role"] == "owner"


# ---------------------------------------------------------------------------
# 3. PATCH /api/v1/projects/{project_id}/members/{user_id} (Update Role)
# ---------------------------------------------------------------------------
def test_update_project_member_role_success(client, setup_project_data):
    """Project Admin promotes MEMBER to ADMIN."""
    proj = setup_project_data["project"]
    proj_admin = setup_project_data["proj_admin"]
    proj_member = setup_project_data["proj_member"]

    resp = client.patch(
        f"/api/v1/projects/{proj.id}/members/{proj_member.id}",
        headers=_auth_header(proj_admin),
        json={"role": "admin"},
    )
    assert resp.status_code == 200
    assert resp.json()["role"] == "admin"


def test_admin_cannot_modify_project_owner_role(client, setup_project_data):
    """Project Admin cannot modify Project OWNER's role (403)."""
    proj = setup_project_data["project"]
    proj_admin = setup_project_data["proj_admin"]
    proj_owner = setup_project_data["proj_owner"]

    resp = client.patch(
        f"/api/v1/projects/{proj.id}/members/{proj_owner.id}",
        headers=_auth_header(proj_admin),
        json={"role": "member"},
    )
    assert resp.status_code == 403
    assert "Cannot modify the role of a project owner" in resp.json()["detail"]


def test_cannot_demote_last_project_owner(client, setup_project_data):
    """Cannot demote the last remaining Project OWNER (400)."""
    proj = setup_project_data["project"]
    proj_owner = setup_project_data["proj_owner"]

    resp = client.patch(
        f"/api/v1/projects/{proj.id}/members/{proj_owner.id}",
        headers=_auth_header(proj_owner),
        json={"role": "admin"},
    )
    assert resp.status_code == 400
    assert "Cannot demote the last owner" in resp.json()["detail"]


def test_owner_can_demote_when_multiple_project_owners_exist(
    client, db_session, setup_project_data
):
    """When multiple project owners exist, demoting one owner succeeds."""
    proj = setup_project_data["project"]
    proj_owner = setup_project_data["proj_owner"]
    co_owner = _create_user(db_session, "co_owner_proj@example.com")
    db_session.add(
        ProjectMember(project_id=proj.id, user_id=co_owner.id, role=RoleType.OWNER)
    )
    db_session.commit()

    resp = client.patch(
        f"/api/v1/projects/{proj.id}/members/{co_owner.id}",
        headers=_auth_header(proj_owner),
        json={"role": "admin"},
    )
    assert resp.status_code == 200
    assert resp.json()["role"] == "admin"


# ---------------------------------------------------------------------------
# 4. DELETE /api/v1/projects/{project_id}/members/{user_id} (Remove Member)
# ---------------------------------------------------------------------------
def test_admin_remove_project_member_success(client, db_session, setup_project_data):
    """Project Admin removes member from project."""
    proj = setup_project_data["project"]
    proj_admin = setup_project_data["proj_admin"]
    proj_member = setup_project_data["proj_member"]

    resp = client.delete(
        f"/api/v1/projects/{proj.id}/members/{proj_member.id}",
        headers=_auth_header(proj_admin),
    )
    assert resp.status_code == 204

    pm = db_session.scalar(
        select(ProjectMember).where(
            ProjectMember.project_id == proj.id,
            ProjectMember.user_id == proj_member.id,
        )
    )
    assert pm is None


def test_admin_cannot_remove_project_owner(client, setup_project_data):
    """Project Admin cannot remove Project OWNER (403)."""
    proj = setup_project_data["project"]
    proj_admin = setup_project_data["proj_admin"]
    proj_owner = setup_project_data["proj_owner"]

    resp = client.delete(
        f"/api/v1/projects/{proj.id}/members/{proj_owner.id}",
        headers=_auth_header(proj_admin),
    )
    assert resp.status_code == 403
    assert "Cannot remove a project owner" in resp.json()["detail"]


def test_cannot_remove_last_project_owner(client, setup_project_data):
    """Cannot remove the last remaining Project OWNER (400)."""
    proj = setup_project_data["project"]
    proj_owner = setup_project_data["proj_owner"]

    resp = client.delete(
        f"/api/v1/projects/{proj.id}/members/{proj_owner.id}",
        headers=_auth_header(proj_owner),
    )
    assert resp.status_code == 400
    assert "Cannot remove the last owner" in resp.json()["detail"]


def test_self_leave_project_success(client, db_session, setup_project_data):
    """A regular member can voluntarily leave the project."""
    proj = setup_project_data["project"]
    proj_member = setup_project_data["proj_member"]

    resp = client.delete(
        f"/api/v1/projects/{proj.id}/members/{proj_member.id}",
        headers=_auth_header(proj_member),
    )
    assert resp.status_code == 204

    pm = db_session.scalar(
        select(ProjectMember).where(
            ProjectMember.project_id == proj.id,
            ProjectMember.user_id == proj_member.id,
        )
    )
    assert pm is None


# ---------------------------------------------------------------------------
# 5. Tiêu chí hoàn thành: Quyền project hoạt động đúng theo role
# ---------------------------------------------------------------------------
def test_project_role_permissions_enforced(client, setup_project_data):
    """Quyền project hoạt động đúng theo role (Viewer/Member cannot update settings, Admin can)."""
    proj = setup_project_data["project"]
    proj_viewer = setup_project_data["proj_viewer"]
    proj_member = setup_project_data["proj_member"]
    proj_admin = setup_project_data["proj_admin"]

    # Viewer can read -> 200
    r1 = client.get(
        f"/api/v1/projects/{proj.id}",
        headers=_auth_header(proj_viewer),
    )
    assert r1.status_code == 200

    # Viewer cannot update project settings -> 403
    r2 = client.patch(
        f"/api/v1/projects/{proj.id}",
        headers=_auth_header(proj_viewer),
        json={"name": "Hacked by Viewer"},
    )
    assert r2.status_code == 403

    # Member cannot update project settings -> 403
    r3 = client.patch(
        f"/api/v1/projects/{proj.id}",
        headers=_auth_header(proj_member),
        json={"name": "Hacked by Member"},
    )
    assert r3.status_code == 403

    # Admin CAN update project settings -> 200
    r4 = client.patch(
        f"/api/v1/projects/{proj.id}",
        headers=_auth_header(proj_admin),
        json={"name": "Legit Admin Update"},
    )
    assert r4.status_code == 200
    assert r4.json()["name"] == "Legit Admin Update"
