import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.core.security import create_access_token, hash_password
from app.db.session import get_db
from app.main import app
from app.models.enums import RoleType
from app.models.membership import ProjectMember, WorkspaceMember
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
def setup_workspace_data(db_session):
    owner = _create_user(db_session, "ws_owner@example.com", "Workspace Owner")
    admin = _create_user(db_session, "ws_admin@example.com", "Workspace Admin")
    member = _create_user(db_session, "ws_member@example.com", "Workspace Member")
    outsider = _create_user(db_session, "outsider@example.com", "Outsider")

    ws = Workspace(name="Core Workspace", slug="core-ws", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.refresh(ws)

    db_session.add_all(
        [
            WorkspaceMember(workspace_id=ws.id, user_id=owner.id, role=RoleType.OWNER),
            WorkspaceMember(workspace_id=ws.id, user_id=admin.id, role=RoleType.ADMIN),
            WorkspaceMember(
                workspace_id=ws.id, user_id=member.id, role=RoleType.MEMBER
            ),
        ]
    )
    db_session.commit()

    return {
        "owner": owner,
        "admin": admin,
        "member": member,
        "outsider": outsider,
        "workspace": ws,
    }


# ---------------------------------------------------------------------------
# 1. POST /api/v1/workspaces/{workspace_id}/projects (Create Project)
# ---------------------------------------------------------------------------
def test_create_project_success(client, db_session, setup_workspace_data):
    """Admin creates project in workspace and becomes Project OWNER."""
    ws = setup_workspace_data["workspace"]
    admin = setup_workspace_data["admin"]

    payload = {
        "name": "Backend Core Platform",
        "key": "BCP",
        "description": "Core services and APIs",
    }
    resp = client.post(
        f"/api/v1/workspaces/{ws.id}/projects",
        headers=_auth_header(admin),
        json=payload,
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["name"] == "Backend Core Platform"
    assert data["key"] == "BCP"
    assert data["workspace_id"] == str(ws.id)
    assert data["id"] is not None

    # Verify membership: creator is Project OWNER
    proj_id = uuid.UUID(data["id"])
    pm = db_session.scalar(
        select(ProjectMember).where(
            ProjectMember.project_id == proj_id,
            ProjectMember.user_id == admin.id,
        )
    )
    assert pm is not None
    assert pm.role == RoleType.OWNER


def test_create_project_key_unique_within_workspace_conflict(
    client, setup_workspace_data
):
    """Key project unique trong workspace (409 Conflict)."""
    ws = setup_workspace_data["workspace"]
    admin = setup_workspace_data["admin"]

    client.post(
        f"/api/v1/workspaces/{ws.id}/projects",
        headers=_auth_header(admin),
        json={"name": "Project One", "key": "DUPKEY"},
    )

    resp2 = client.post(
        f"/api/v1/workspaces/{ws.id}/projects",
        headers=_auth_header(admin),
        json={"name": "Project Two", "key": "DUPKEY"},
    )
    assert resp2.status_code == 409
    assert "already exists in this workspace" in resp2.json()["detail"]


def test_create_project_same_key_in_different_workspaces_allowed(
    client, db_session, setup_workspace_data
):
    """Same project key in different workspaces is allowed."""
    ws1 = setup_workspace_data["workspace"]
    owner = setup_workspace_data["owner"]

    # Create project in WS1
    resp1 = client.post(
        f"/api/v1/workspaces/{ws1.id}/projects",
        headers=_auth_header(owner),
        json={"name": "Project Alpha WS1", "key": "SHARED"},
    )
    assert resp1.status_code == 201

    # Create second workspace
    ws2 = Workspace(name="Second WS", slug="second-ws", owner_id=owner.id)
    db_session.add(ws2)
    db_session.commit()
    db_session.refresh(ws2)
    db_session.add(
        WorkspaceMember(workspace_id=ws2.id, user_id=owner.id, role=RoleType.OWNER)
    )
    db_session.commit()

    # Create project with same key in WS2
    resp2 = client.post(
        f"/api/v1/workspaces/{ws2.id}/projects",
        headers=_auth_header(owner),
        json={"name": "Project Alpha WS2", "key": "SHARED"},
    )
    assert resp2.status_code == 201


def test_create_project_validation_failure(client, setup_workspace_data):
    """Invalid key pattern (lowercase or symbols) returns 422."""
    ws = setup_workspace_data["workspace"]
    admin = setup_workspace_data["admin"]

    # Lowercase key
    resp = client.post(
        f"/api/v1/workspaces/{ws.id}/projects",
        headers=_auth_header(admin),
        json={"name": "Project", "key": "lower"},
    )
    assert resp.status_code == 422

    # Key with hyphen
    resp2 = client.post(
        f"/api/v1/workspaces/{ws.id}/projects",
        headers=_auth_header(admin),
        json={"name": "Project", "key": "KEY-1"},
    )
    assert resp2.status_code == 422


def test_create_project_as_member_forbidden(client, setup_workspace_data):
    """Regular workspace member cannot create projects (403)."""
    ws = setup_workspace_data["workspace"]
    member = setup_workspace_data["member"]

    resp = client.post(
        f"/api/v1/workspaces/{ws.id}/projects",
        headers=_auth_header(member),
        json={"name": "Forbidden Project", "key": "FORBID"},
    )
    assert resp.status_code == 403


def test_create_project_as_outsider_404(client, setup_workspace_data):
    """User outside workspace gets 404."""
    ws = setup_workspace_data["workspace"]
    outsider = setup_workspace_data["outsider"]

    resp = client.post(
        f"/api/v1/workspaces/{ws.id}/projects",
        headers=_auth_header(outsider),
        json={"name": "Outsider Project", "key": "OUTS"},
    )
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# 2. GET /api/v1/workspaces/{workspace_id}/projects (List & Pagination)
# ---------------------------------------------------------------------------
def test_list_projects_pagination(client, setup_workspace_data):
    """List projects returns paginated response (items, total, page, total_pages)."""
    ws = setup_workspace_data["workspace"]
    admin = setup_workspace_data["admin"]
    member = setup_workspace_data["member"]

    # Create 5 projects
    for i in range(1, 6):
        client.post(
            f"/api/v1/workspaces/{ws.id}/projects",
            headers=_auth_header(admin),
            json={"name": f"Project {i}", "key": f"PRJ{i}"},
        )

    # Page 1, page_size 2
    resp1 = client.get(
        f"/api/v1/workspaces/{ws.id}/projects?page=1&page_size=2",
        headers=_auth_header(member),
    )
    assert resp1.status_code == 200
    data1 = resp1.json()
    assert len(data1["items"]) == 2
    assert data1["total"] == 5
    assert data1["page"] == 1
    assert data1["page_size"] == 2
    assert data1["total_pages"] == 3

    # Page 3, page_size 2 -> should have 1 item
    resp3 = client.get(
        f"/api/v1/workspaces/{ws.id}/projects?page=3&page_size=2",
        headers=_auth_header(member),
    )
    assert resp3.status_code == 200
    assert len(resp3.json()["items"]) == 1


def test_list_projects_only_workspace_members_can_see(client, setup_workspace_data):
    """Chỉ thành viên workspace thấy project tương ứng (outsider receives 404)."""
    ws = setup_workspace_data["workspace"]
    outsider = setup_workspace_data["outsider"]

    resp = client.get(
        f"/api/v1/workspaces/{ws.id}/projects",
        headers=_auth_header(outsider),
    )
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# 3. GET /api/v1/projects/{project_id} (Read Project)
# ---------------------------------------------------------------------------
def test_get_project_by_id_success(client, setup_workspace_data):
    """Workspace admin or project member can retrieve project details."""
    ws = setup_workspace_data["workspace"]
    admin = setup_workspace_data["admin"]

    create_resp = client.post(
        f"/api/v1/workspaces/{ws.id}/projects",
        headers=_auth_header(admin),
        json={"name": "Apollo Project", "key": "APO"},
    )
    proj_id = create_resp.json()["id"]

    resp = client.get(
        f"/api/v1/projects/{proj_id}",
        headers=_auth_header(admin),
    )
    assert resp.status_code == 200
    assert resp.json()["id"] == proj_id
    assert resp.json()["key"] == "APO"


def test_get_project_by_id_outsider_404(client, setup_workspace_data):
    """User outside receives 404."""
    ws = setup_workspace_data["workspace"]
    admin = setup_workspace_data["admin"]
    outsider = setup_workspace_data["outsider"]

    create_resp = client.post(
        f"/api/v1/workspaces/{ws.id}/projects",
        headers=_auth_header(admin),
        json={"name": "Secret Project", "key": "SEC"},
    )
    proj_id = create_resp.json()["id"]

    resp = client.get(
        f"/api/v1/projects/{proj_id}",
        headers=_auth_header(outsider),
    )
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# 4. PATCH /api/v1/projects/{project_id} (Update Project)
# ---------------------------------------------------------------------------
def test_update_project_success(client, setup_workspace_data):
    """Admin updates project details."""
    ws = setup_workspace_data["workspace"]
    admin = setup_workspace_data["admin"]

    create_resp = client.post(
        f"/api/v1/workspaces/{ws.id}/projects",
        headers=_auth_header(admin),
        json={"name": "Original Project", "key": "ORIG"},
    )
    proj_id = create_resp.json()["id"]

    resp = client.patch(
        f"/api/v1/projects/{proj_id}",
        headers=_auth_header(admin),
        json={
            "name": "Updated Project Name",
            "key": "UPD1",
            "description": "New description",
        },
    )
    assert resp.status_code == 200
    assert resp.json()["name"] == "Updated Project Name"
    assert resp.json()["key"] == "UPD1"
    assert resp.json()["description"] == "New description"


def test_update_project_key_conflict(client, setup_workspace_data):
    """Updating project key to an already taken key returns 409."""
    ws = setup_workspace_data["workspace"]
    admin = setup_workspace_data["admin"]

    client.post(
        f"/api/v1/workspaces/{ws.id}/projects",
        headers=_auth_header(admin),
        json={"name": "First Project", "key": "KEY1"},
    )
    p2 = client.post(
        f"/api/v1/workspaces/{ws.id}/projects",
        headers=_auth_header(admin),
        json={"name": "Second Project", "key": "KEY2"},
    )
    p2_id = p2.json()["id"]

    resp = client.patch(
        f"/api/v1/projects/{p2_id}",
        headers=_auth_header(admin),
        json={"key": "KEY1"},
    )
    assert resp.status_code == 409


# ---------------------------------------------------------------------------
# 5. DELETE & RESTORE /api/v1/projects/{project_id} (Archive / Restore)
# ---------------------------------------------------------------------------
def test_archive_and_restore_project(client, db_session, setup_workspace_data):
    """Archive (soft delete) project and restore it."""
    ws = setup_workspace_data["workspace"]
    admin = setup_workspace_data["admin"]

    create_resp = client.post(
        f"/api/v1/workspaces/{ws.id}/projects",
        headers=_auth_header(admin),
        json={"name": "Archive Me", "key": "ARCH"},
    )
    proj_id = create_resp.json()["id"]

    # Archive (DELETE -> 204)
    del_resp = client.delete(
        f"/api/v1/projects/{proj_id}",
        headers=_auth_header(admin),
    )
    assert del_resp.status_code == 204

    # Subsequent GET returns 404
    get_resp = client.get(
        f"/api/v1/projects/{proj_id}",
        headers=_auth_header(admin),
    )
    assert get_resp.status_code == 404

    # Excluded from list by default
    list_resp = client.get(
        f"/api/v1/workspaces/{ws.id}/projects",
        headers=_auth_header(admin),
    )
    assert not any(p["id"] == proj_id for p in list_resp.json()["items"])

    # Included if include_archived=true
    list_arch = client.get(
        f"/api/v1/workspaces/{ws.id}/projects?include_archived=true",
        headers=_auth_header(admin),
    )
    assert any(p["id"] == proj_id for p in list_arch.json()["items"])

    # Restore project
    restore_resp = client.post(
        f"/api/v1/projects/{proj_id}/restore",
        headers=_auth_header(admin),
    )
    assert restore_resp.status_code == 200
    assert restore_resp.json()["deleted_at"] is None

    # Now GET returns 200 again
    get_again = client.get(
        f"/api/v1/projects/{proj_id}",
        headers=_auth_header(admin),
    )
    assert get_again.status_code == 200
