import uuid

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
def setup_workspace(db_session):
    owner = _create_user(db_session, "owner@example.com", "Workspace Owner")
    admin = _create_user(db_session, "admin@example.com", "Workspace Admin")
    member = _create_user(db_session, "member@example.com", "Workspace Member")
    viewer = _create_user(db_session, "viewer@example.com", "Workspace Viewer")
    outsider = _create_user(db_session, "outsider@example.com", "Outsider User")

    ws = Workspace(name="Team Workspace", slug="team-ws", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.refresh(ws)

    # Memberships
    db_session.add_all(
        [
            WorkspaceMember(workspace_id=ws.id, user_id=owner.id, role=RoleType.OWNER),
            WorkspaceMember(workspace_id=ws.id, user_id=admin.id, role=RoleType.ADMIN),
            WorkspaceMember(
                workspace_id=ws.id, user_id=member.id, role=RoleType.MEMBER
            ),
            WorkspaceMember(
                workspace_id=ws.id, user_id=viewer.id, role=RoleType.VIEWER
            ),
        ]
    )
    db_session.commit()

    return {
        "owner": owner,
        "admin": admin,
        "member": member,
        "viewer": viewer,
        "outsider": outsider,
        "workspace": ws,
    }


# ---------------------------------------------------------------------------
# 1. GET /api/v1/workspaces/{workspace_id}/members (List Members)
# ---------------------------------------------------------------------------
def test_list_workspace_members_success(client, setup_workspace):
    """Members with VIEWER role can list all members with user details."""
    ws = setup_workspace["workspace"]
    viewer = setup_workspace["viewer"]

    resp = client.get(
        f"/api/v1/workspaces/{ws.id}/members",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 200
    members = resp.json()
    assert len(members) == 4
    # Verify user information is included
    user_emails = [m["user"]["email"] for m in members if m.get("user")]
    assert "owner@example.com" in user_emails
    assert "admin@example.com" in user_emails


def test_list_workspace_members_outsider_404(client, setup_workspace):
    """User outside workspace cannot view members (404)."""
    ws = setup_workspace["workspace"]
    outsider = setup_workspace["outsider"]

    resp = client.get(
        f"/api/v1/workspaces/{ws.id}/members",
        headers=_auth_header(outsider),
    )
    assert resp.status_code == 404


def test_list_workspace_members_unauthenticated(client, setup_workspace):
    """Listing without token returns 401."""
    ws = setup_workspace["workspace"]
    resp = client.get(f"/api/v1/workspaces/{ws.id}/members")
    assert resp.status_code == 401


# ---------------------------------------------------------------------------
# 2. POST /api/v1/workspaces/{workspace_id}/members (Add/Invite Member)
# ---------------------------------------------------------------------------
def test_add_member_by_user_id_success(client, db_session, setup_workspace):
    """Admin adds new member by user_id."""
    ws = setup_workspace["workspace"]
    admin = setup_workspace["admin"]
    new_user = _create_user(db_session, "newbee@example.com", "Newbee User")

    resp = client.post(
        f"/api/v1/workspaces/{ws.id}/members",
        headers=_auth_header(admin),
        json={"user_id": str(new_user.id), "role": "member"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["role"] == "member"
    assert data["user_id"] == str(new_user.id)
    assert data["user"]["email"] == "newbee@example.com"


def test_add_member_by_email_success(client, db_session, setup_workspace):
    """Admin adds new member by email address."""
    ws = setup_workspace["workspace"]
    admin = setup_workspace["admin"]
    new_user = _create_user(db_session, "invitee@example.com", "Invitee User")

    resp = client.post(
        f"/api/v1/workspaces/{ws.id}/members",
        headers=_auth_header(admin),
        json={"email": "invitee@example.com", "role": "viewer"},
    )
    assert resp.status_code == 201
    assert resp.json()["role"] == "viewer"
    assert resp.json()["user_id"] == str(new_user.id)


def test_add_member_already_member_conflict(client, setup_workspace):
    """Attempting to add an existing member returns 409 Conflict."""
    ws = setup_workspace["workspace"]
    admin = setup_workspace["admin"]
    member = setup_workspace["member"]

    resp = client.post(
        f"/api/v1/workspaces/{ws.id}/members",
        headers=_auth_header(admin),
        json={"user_id": str(member.id), "role": "member"},
    )
    assert resp.status_code == 409
    assert "already a member" in resp.json()["detail"]


def test_add_member_user_not_found(client, setup_workspace):
    """Non-existent user returns 404."""
    ws = setup_workspace["workspace"]
    admin = setup_workspace["admin"]

    resp = client.post(
        f"/api/v1/workspaces/{ws.id}/members",
        headers=_auth_header(admin),
        json={"user_id": str(uuid.uuid4())},
    )
    assert resp.status_code == 404


def test_add_member_as_member_forbidden(client, db_session, setup_workspace):
    """Regular member cannot add members (403)."""
    ws = setup_workspace["workspace"]
    member = setup_workspace["member"]
    new_user = _create_user(db_session, "someone@example.com")

    resp = client.post(
        f"/api/v1/workspaces/{ws.id}/members",
        headers=_auth_header(member),
        json={"user_id": str(new_user.id)},
    )
    assert resp.status_code == 403


def test_admin_cannot_add_owner_forbidden(client, db_session, setup_workspace):
    """Admin cannot assign the OWNER role (403)."""
    ws = setup_workspace["workspace"]
    admin = setup_workspace["admin"]
    new_user = _create_user(db_session, "co_owner_target@example.com")

    resp = client.post(
        f"/api/v1/workspaces/{ws.id}/members",
        headers=_auth_header(admin),
        json={"user_id": str(new_user.id), "role": "owner"},
    )
    assert resp.status_code == 403
    assert "Only workspace owners" in resp.json()["detail"]


def test_owner_can_add_another_owner_success(client, db_session, setup_workspace):
    """Owner can directly assign the OWNER role to a new member."""
    ws = setup_workspace["workspace"]
    owner = setup_workspace["owner"]
    new_user = _create_user(db_session, "new_owner@example.com")

    resp = client.post(
        f"/api/v1/workspaces/{ws.id}/members",
        headers=_auth_header(owner),
        json={"user_id": str(new_user.id), "role": "owner"},
    )
    assert resp.status_code == 201
    assert resp.json()["role"] == "owner"


# ---------------------------------------------------------------------------
# 3. PATCH /api/v1/workspaces/{workspace_id}/members/{user_id} (Change Role)
# ---------------------------------------------------------------------------
def test_update_member_role_success(client, db_session, setup_workspace):
    """Admin promotes MEMBER to ADMIN."""
    ws = setup_workspace["workspace"]
    admin = setup_workspace["admin"]
    member = setup_workspace["member"]

    resp = client.patch(
        f"/api/v1/workspaces/{ws.id}/members/{member.id}",
        headers=_auth_header(admin),
        json={"role": "admin"},
    )
    assert resp.status_code == 200
    assert resp.json()["role"] == "admin"


def test_admin_cannot_modify_owner_role(client, setup_workspace):
    """Admin cannot modify an OWNER role (403)."""
    ws = setup_workspace["workspace"]
    admin = setup_workspace["admin"]
    owner = setup_workspace["owner"]

    resp = client.patch(
        f"/api/v1/workspaces/{ws.id}/members/{owner.id}",
        headers=_auth_header(admin),
        json={"role": "member"},
    )
    assert resp.status_code == 403
    assert "Cannot modify the role of a workspace owner" in resp.json()["detail"]


def test_admin_cannot_promote_to_owner(client, setup_workspace):
    """Admin cannot promote anyone to OWNER (403)."""
    ws = setup_workspace["workspace"]
    admin = setup_workspace["admin"]
    member = setup_workspace["member"]

    resp = client.patch(
        f"/api/v1/workspaces/{ws.id}/members/{member.id}",
        headers=_auth_header(admin),
        json={"role": "owner"},
    )
    assert resp.status_code == 403
    assert "Only workspace owners" in resp.json()["detail"]


def test_cannot_demote_last_owner(client, setup_workspace):
    """Cannot demote the last remaining OWNER of the workspace (400)."""
    ws = setup_workspace["workspace"]
    owner = setup_workspace["owner"]

    resp = client.patch(
        f"/api/v1/workspaces/{ws.id}/members/{owner.id}",
        headers=_auth_header(owner),
        json={"role": "admin"},
    )
    assert resp.status_code == 400
    assert "Cannot demote the last owner" in resp.json()["detail"]


def test_owner_can_demote_when_multiple_owners_exist(
    client, db_session, setup_workspace
):
    """When multiple owners exist, an owner can be demoted."""
    ws = setup_workspace["workspace"]
    owner = setup_workspace["owner"]
    co_owner = _create_user(db_session, "co_owner2@example.com")
    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=co_owner.id, role=RoleType.OWNER)
    )
    db_session.commit()

    # Demote co_owner to ADMIN
    resp = client.patch(
        f"/api/v1/workspaces/{ws.id}/members/{co_owner.id}",
        headers=_auth_header(owner),
        json={"role": "admin"},
    )
    assert resp.status_code == 200
    assert resp.json()["role"] == "admin"


# ---------------------------------------------------------------------------
# 4. DELETE /api/v1/workspaces/{workspace_id}/members/{user_id} (Remove Member)
# ---------------------------------------------------------------------------
def test_admin_remove_member_success(client, db_session, setup_workspace):
    """Admin removes member from workspace."""
    ws = setup_workspace["workspace"]
    admin = setup_workspace["admin"]
    member = setup_workspace["member"]

    resp = client.delete(
        f"/api/v1/workspaces/{ws.id}/members/{member.id}",
        headers=_auth_header(admin),
    )
    assert resp.status_code == 204

    # Verify deleted from DB
    wm = db_session.scalar(
        select(WorkspaceMember).where(
            WorkspaceMember.workspace_id == ws.id,
            WorkspaceMember.user_id == member.id,
        )
    )
    assert wm is None


def test_admin_cannot_remove_owner(client, setup_workspace):
    """Admin cannot remove an OWNER (403)."""
    ws = setup_workspace["workspace"]
    admin = setup_workspace["admin"]
    owner = setup_workspace["owner"]

    resp = client.delete(
        f"/api/v1/workspaces/{ws.id}/members/{owner.id}",
        headers=_auth_header(admin),
    )
    assert resp.status_code == 403
    assert "Cannot remove a workspace owner" in resp.json()["detail"]


def test_cannot_remove_last_owner(client, setup_workspace):
    """Cannot remove the last remaining OWNER of the workspace (400)."""
    ws = setup_workspace["workspace"]
    owner = setup_workspace["owner"]

    resp = client.delete(
        f"/api/v1/workspaces/{ws.id}/members/{owner.id}",
        headers=_auth_header(owner),
    )
    assert resp.status_code == 400
    assert "Cannot remove the last owner" in resp.json()["detail"]


def test_self_leave_workspace_success(client, db_session, setup_workspace):
    """A regular member can voluntarily leave the workspace."""
    ws = setup_workspace["workspace"]
    member = setup_workspace["member"]

    resp = client.delete(
        f"/api/v1/workspaces/{ws.id}/members/{member.id}",
        headers=_auth_header(member),
    )
    assert resp.status_code == 204

    wm = db_session.scalar(
        select(WorkspaceMember).where(
            WorkspaceMember.workspace_id == ws.id,
            WorkspaceMember.user_id == member.id,
        )
    )
    assert wm is None


def test_member_cannot_remove_other_member(client, setup_workspace):
    """Regular member cannot remove another member (403)."""
    ws = setup_workspace["workspace"]
    member = setup_workspace["member"]
    viewer = setup_workspace["viewer"]

    resp = client.delete(
        f"/api/v1/workspaces/{ws.id}/members/{viewer.id}",
        headers=_auth_header(member),
    )
    assert resp.status_code == 403


def test_remove_member_cleans_up_project_memberships(
    client, db_session, setup_workspace
):
    """Removing a user from a workspace also cascades to clean up project memberships."""
    ws = setup_workspace["workspace"]
    owner = setup_workspace["owner"]
    member = setup_workspace["member"]

    # Create project in workspace and add member to project
    proj = Project(name="Project Omega", key="OMG", workspace_id=ws.id)
    db_session.add(proj)
    db_session.commit()
    db_session.refresh(proj)

    db_session.add(
        ProjectMember(project_id=proj.id, user_id=member.id, role=RoleType.MEMBER)
    )
    db_session.commit()

    # Admin/Owner removes member from workspace
    resp = client.delete(
        f"/api/v1/workspaces/{ws.id}/members/{member.id}",
        headers=_auth_header(owner),
    )
    assert resp.status_code == 204

    # Verify ProjectMember was also cleaned up
    pm = db_session.scalar(
        select(ProjectMember).where(
            ProjectMember.project_id == proj.id,
            ProjectMember.user_id == member.id,
        )
    )
    assert pm is None
