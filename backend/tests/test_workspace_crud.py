import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.core.security import create_access_token, hash_password
from app.db.session import get_db
from app.main import app
from app.models.enums import RoleType
from app.models.membership import WorkspaceMember
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


# ---------------------------------------------------------------------------
# 1. POST /api/v1/workspaces (Create Workspace)
# ---------------------------------------------------------------------------
def test_create_workspace_success(client, db_session):
    """Creator automatically becomes the workspace OWNER."""
    user = _create_user(db_session, "creator@example.com")

    payload = {
        "name": "Acme Innovations",
        "slug": "acme-innovations",
        "description": "Tech hub workspace",
    }
    response = client.post(
        "/api/v1/workspaces",
        headers=_auth_header(user),
        json=payload,
    )

    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Acme Innovations"
    assert data["slug"] == "acme-innovations"
    assert data["description"] == "Tech hub workspace"
    assert data["owner_id"] == str(user.id)
    assert data["id"] is not None

    # Verify membership table: Creator must be OWNER
    workspace_id = uuid.UUID(data["id"])
    member = db_session.scalar(
        select(WorkspaceMember).where(
            WorkspaceMember.workspace_id == workspace_id,
            WorkspaceMember.user_id == user.id,
        )
    )
    assert member is not None
    assert member.role == RoleType.OWNER


def test_create_workspace_duplicate_slug_conflict(client, db_session):
    """Creating workspace with already existing slug returns 409 Conflict."""
    user = _create_user(db_session, "owner1@example.com")
    payload = {"name": "First Space", "slug": "duplicate-slug"}
    client.post("/api/v1/workspaces", headers=_auth_header(user), json=payload)

    # Second attempt with same slug
    user2 = _create_user(db_session, "owner2@example.com")
    resp2 = client.post(
        "/api/v1/workspaces",
        headers=_auth_header(user2),
        json={"name": "Second Space", "slug": "duplicate-slug"},
    )
    assert resp2.status_code == 409
    assert "already exists" in resp2.json()["detail"]


def test_create_workspace_unauthenticated(client):
    """Creating workspace without token returns 401."""
    resp = client.post(
        "/api/v1/workspaces",
        json={"name": "Space", "slug": "space"},
    )
    assert resp.status_code == 401


def test_create_workspace_validation_failure(client, db_session):
    """Blank name or invalid slug format returns 422."""
    user = _create_user(db_session, "valid_user@example.com")

    # Blank name
    resp1 = client.post(
        "/api/v1/workspaces",
        headers=_auth_header(user),
        json={"name": "   ", "slug": "valid-slug"},
    )
    assert resp1.status_code == 422

    # Invalid slug (uppercase or special characters)
    resp2 = client.post(
        "/api/v1/workspaces",
        headers=_auth_header(user),
        json={"name": "Valid Name", "slug": "INVALID_SLUG!"},
    )
    assert resp2.status_code == 422


# ---------------------------------------------------------------------------
# 2. GET /api/v1/workspaces (List Workspaces)
# ---------------------------------------------------------------------------
def test_list_workspaces_only_user_memberships(client, db_session):
    """Listing returns only workspaces where the authenticated user is a member."""
    user_a = _create_user(db_session, "user_a@example.com")
    user_b = _create_user(db_session, "user_b@example.com")
    user_c = _create_user(db_session, "user_c@example.com")

    # User A creates 2 workspaces
    client.post(
        "/api/v1/workspaces",
        headers=_auth_header(user_a),
        json={"name": "A Space 1", "slug": "a-space-1"},
    )
    client.post(
        "/api/v1/workspaces",
        headers=_auth_header(user_a),
        json={"name": "A Space 2", "slug": "a-space-2"},
    )

    # User B creates 1 workspace
    client.post(
        "/api/v1/workspaces",
        headers=_auth_header(user_b),
        json={"name": "B Space", "slug": "b-space"},
    )

    # User A lists
    resp_a = client.get("/api/v1/workspaces", headers=_auth_header(user_a))
    assert resp_a.status_code == 200
    slugs_a = [w["slug"] for w in resp_a.json()]
    assert set(slugs_a) == {"a-space-1", "a-space-2"}

    # User B lists
    resp_b = client.get("/api/v1/workspaces", headers=_auth_header(user_b))
    assert resp_b.status_code == 200
    slugs_b = [w["slug"] for w in resp_b.json()]
    assert slugs_b == ["b-space"]

    # User C (outsider with no memberships) lists
    resp_c = client.get("/api/v1/workspaces", headers=_auth_header(user_c))
    assert resp_c.status_code == 200
    assert resp_c.json() == []


def test_list_workspaces_unauthenticated(client):
    """Listing workspaces without token returns 401."""
    resp = client.get("/api/v1/workspaces")
    assert resp.status_code == 401


# ---------------------------------------------------------------------------
# 3. GET /api/v1/workspaces/{workspace_id} (Read Workspace)
# ---------------------------------------------------------------------------
def test_get_workspace_by_id_success(client, db_session):
    """Members with at least VIEWER role can retrieve workspace details."""
    owner = _create_user(db_session, "ws_owner@example.com")
    viewer = _create_user(db_session, "ws_viewer@example.com")

    ws = Workspace(name="Test Space", slug="test-space", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.refresh(ws)

    # Add owner and viewer
    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=owner.id, role=RoleType.OWNER)
    )
    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=viewer.id, role=RoleType.VIEWER)
    )
    db_session.commit()

    # Viewer retrieves workspace
    resp = client.get(
        f"/api/v1/workspaces/{ws.id}",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 200
    assert resp.json()["id"] == str(ws.id)
    assert resp.json()["slug"] == "test-space"


def test_get_workspace_by_id_outsider_404(client, db_session):
    """User outside workspace receives 404 Not Found."""
    owner = _create_user(db_session, "owner_out@example.com")
    outsider = _create_user(db_session, "outsider_out@example.com")

    ws = Workspace(name="Private Space", slug="private-space", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.refresh(ws)
    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=owner.id, role=RoleType.OWNER)
    )
    db_session.commit()

    resp = client.get(
        f"/api/v1/workspaces/{ws.id}",
        headers=_auth_header(outsider),
    )
    assert resp.status_code == 404
    assert resp.json()["detail"] == "Workspace not found."


# ---------------------------------------------------------------------------
# 4. PATCH /api/v1/workspaces/{workspace_id} (Update Workspace)
# ---------------------------------------------------------------------------
def test_update_workspace_as_owner_and_admin_success(client, db_session):
    """Both OWNER and ADMIN can update workspace details."""
    owner = _create_user(db_session, "upd_owner@example.com")
    admin = _create_user(db_session, "upd_admin@example.com")

    ws = Workspace(name="Original Name", slug="original-slug", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.refresh(ws)

    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=owner.id, role=RoleType.OWNER)
    )
    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=admin.id, role=RoleType.ADMIN)
    )
    db_session.commit()

    # Admin updates name
    resp_admin = client.patch(
        f"/api/v1/workspaces/{ws.id}",
        headers=_auth_header(admin),
        json={"name": "Admin Renamed Space"},
    )
    assert resp_admin.status_code == 200
    assert resp_admin.json()["name"] == "Admin Renamed Space"

    # Owner updates slug and description
    resp_owner = client.patch(
        f"/api/v1/workspaces/{ws.id}",
        headers=_auth_header(owner),
        json={"slug": "owner-new-slug", "description": "New description"},
    )
    assert resp_owner.status_code == 200
    assert resp_owner.json()["slug"] == "owner-new-slug"
    assert resp_owner.json()["description"] == "New description"


def test_update_workspace_as_member_and_viewer_forbidden(client, db_session):
    """MEMBER and VIEWER are forbidden from updating workspace (403)."""
    owner = _create_user(db_session, "perm_owner@example.com")
    member = _create_user(db_session, "perm_member@example.com")
    viewer = _create_user(db_session, "perm_viewer@example.com")

    ws = Workspace(name="Protected Space", slug="prot-slug", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.refresh(ws)

    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=owner.id, role=RoleType.OWNER)
    )
    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=member.id, role=RoleType.MEMBER)
    )
    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=viewer.id, role=RoleType.VIEWER)
    )
    db_session.commit()

    # Member attempt -> 403
    resp_m = client.patch(
        f"/api/v1/workspaces/{ws.id}",
        headers=_auth_header(member),
        json={"name": "Hacked by Member"},
    )
    assert resp_m.status_code == 403

    # Viewer attempt -> 403
    resp_v = client.patch(
        f"/api/v1/workspaces/{ws.id}",
        headers=_auth_header(viewer),
        json={"name": "Hacked by Viewer"},
    )
    assert resp_v.status_code == 403


def test_update_workspace_duplicate_slug_conflict(client, db_session):
    """Updating slug to an existing workspace slug returns 409 Conflict."""
    owner = _create_user(db_session, "dup_upd_owner@example.com")

    ws1 = Workspace(name="Space 1", slug="space-1", owner_id=owner.id)
    ws2 = Workspace(name="Space 2", slug="space-2", owner_id=owner.id)
    db_session.add_all([ws1, ws2])
    db_session.commit()
    db_session.refresh(ws1)
    db_session.refresh(ws2)

    db_session.add(
        WorkspaceMember(workspace_id=ws1.id, user_id=owner.id, role=RoleType.OWNER)
    )
    db_session.add(
        WorkspaceMember(workspace_id=ws2.id, user_id=owner.id, role=RoleType.OWNER)
    )
    db_session.commit()

    # Try updating ws2 slug to "space-1"
    resp = client.patch(
        f"/api/v1/workspaces/{ws2.id}",
        headers=_auth_header(owner),
        json={"slug": "space-1"},
    )
    assert resp.status_code == 409


# ---------------------------------------------------------------------------
# 5. DELETE /api/v1/workspaces/{workspace_id} (Delete Workspace)
# ---------------------------------------------------------------------------
def test_delete_workspace_as_owner_and_admin_success(client, db_session):
    """Owner and Admin can soft delete workspace."""
    owner = _create_user(db_session, "del_owner@example.com")
    admin = _create_user(db_session, "del_admin@example.com")

    ws = Workspace(name="To Delete", slug="to-delete", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.refresh(ws)

    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=owner.id, role=RoleType.OWNER)
    )
    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=admin.id, role=RoleType.ADMIN)
    )
    db_session.commit()

    # Admin deletes workspace
    resp = client.delete(
        f"/api/v1/workspaces/{ws.id}",
        headers=_auth_header(admin),
    )
    assert resp.status_code == 204

    # Verify soft delete
    db_session.refresh(ws)
    assert ws.deleted_at is not None

    # Subsequent GET returns 404
    resp_get = client.get(
        f"/api/v1/workspaces/{ws.id}",
        headers=_auth_header(owner),
    )
    assert resp_get.status_code == 404


def test_delete_workspace_as_member_forbidden(client, db_session):
    """Regular member cannot delete workspace (403)."""
    owner = _create_user(db_session, "del_perm_owner@example.com")
    member = _create_user(db_session, "del_perm_member@example.com")

    ws = Workspace(name="No Delete Space", slug="no-del", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.refresh(ws)

    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=owner.id, role=RoleType.OWNER)
    )
    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=member.id, role=RoleType.MEMBER)
    )
    db_session.commit()

    resp = client.delete(
        f"/api/v1/workspaces/{ws.id}",
        headers=_auth_header(member),
    )
    assert resp.status_code == 403
