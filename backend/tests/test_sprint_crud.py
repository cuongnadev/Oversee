import uuid
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from app.core.security import create_access_token, hash_password
from app.db.session import get_db
from app.main import app
from app.models.enums import (
    IssuePriority,
    IssueStatus,
    IssueType,
    RoleType,
)
from app.models.issue import Issue
from app.models.membership import ProjectMember, WorkspaceMember
from app.models.project import Project
from app.models.user import User
from app.models.workspace import Workspace


# ---------------------------------------------------------------------------
# Helpers & Fixtures
# ---------------------------------------------------------------------------
def _create_user(
    db_session,
    email="user@example.com",
    full_name="Test User",
    is_active=True,
) -> User:
    user = User(
        email=email.lower().strip(),
        hashed_password=hash_password("Password123!"),
        full_name=full_name,
        is_active=is_active,
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
def setup_sprint_data(db_session):
    ws_owner = _create_user(db_session, "ws_owner@example.com", "Workspace Owner")
    proj_admin = _create_user(db_session, "admin@example.com", "Project Admin")
    m1 = _create_user(db_session, "member1@example.com", "Member 1")
    viewer = _create_user(db_session, "viewer@example.com", "Viewer")
    outsider = _create_user(db_session, "outsider@example.com", "Outsider")

    ws = Workspace(name="Sprint Workspace", slug="sprint-ws", owner_id=ws_owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.refresh(ws)

    for u, r in [
        (ws_owner, RoleType.OWNER),
        (proj_admin, RoleType.ADMIN),
        (m1, RoleType.MEMBER),
        (viewer, RoleType.VIEWER),
    ]:
        db_session.add(WorkspaceMember(workspace_id=ws.id, user_id=u.id, role=r))
    db_session.commit()

    proj = Project(
        workspace_id=ws.id,
        name="Sprint Project",
        key="SPR",
    )
    db_session.add(proj)
    db_session.commit()
    db_session.refresh(proj)

    for u, r in [
        (proj_admin, RoleType.ADMIN),
        (m1, RoleType.MEMBER),
        (viewer, RoleType.VIEWER),
    ]:
        db_session.add(ProjectMember(project_id=proj.id, user_id=u.id, role=r))
    db_session.commit()

    return {
        "ws_owner": ws_owner,
        "admin": proj_admin,
        "member": m1,
        "viewer": viewer,
        "outsider": outsider,
        "workspace": ws,
        "project": proj,
    }


# ---------------------------------------------------------------------------
# Test Cases
# ---------------------------------------------------------------------------
def test_create_sprint_success(client, setup_sprint_data):
    """Member can create a planned sprint with valid start and end dates."""
    data = setup_sprint_data
    proj_id = data["project"].id

    start = datetime.now(UTC) + timedelta(days=1)
    end = start + timedelta(days=14)

    payload = {
        "name": "Sprint Alpha",
        "goal": "Deliver MVP core",
        "start_date": start.isoformat(),
        "end_date": end.isoformat(),
        "status": "planned",
    }
    resp = client.post(
        f"/api/v1/projects/{proj_id}/sprints",
        json=payload,
        headers=_auth_header(data["member"]),
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["name"] == "Sprint Alpha"
    assert body["goal"] == "Deliver MVP core"
    assert body["status"] == "planned"
    assert body["project_id"] == str(proj_id)
    assert "id" in body


def test_create_sprint_via_sprints_endpoint(client, setup_sprint_data):
    """Can also create sprint directly via /api/v1/sprints with project_id in body."""
    data = setup_sprint_data
    proj_id = data["project"].id

    payload = {
        "project_id": str(proj_id),
        "name": "Sprint Direct",
        "goal": "Direct creation",
        "status": "planned",
    }
    resp = client.post(
        "/api/v1/sprints",
        json=payload,
        headers=_auth_header(data["member"]),
    )
    assert resp.status_code == 201
    assert resp.json()["name"] == "Sprint Direct"


def test_create_sprint_invalid_dates(client, setup_sprint_data):
    """Validation error (422) if start_date >= end_date."""
    data = setup_sprint_data
    proj_id = data["project"].id

    now = datetime.now(UTC)
    # start_date > end_date
    payload = {
        "name": "Invalid Sprint 1",
        "start_date": (now + timedelta(days=10)).isoformat(),
        "end_date": (now + timedelta(days=5)).isoformat(),
    }
    resp = client.post(
        f"/api/v1/projects/{proj_id}/sprints",
        json=payload,
        headers=_auth_header(data["member"]),
    )
    assert resp.status_code == 422

    # start_date == end_date
    payload2 = {
        "name": "Invalid Sprint 2",
        "start_date": now.isoformat(),
        "end_date": now.isoformat(),
    }
    resp2 = client.post(
        f"/api/v1/projects/{proj_id}/sprints",
        json=payload2,
        headers=_auth_header(data["member"]),
    )
    assert resp2.status_code == 422


def test_sprint_update_invalid_dates(client, setup_sprint_data):
    """Updating sprint dates such that start_date >= end_date fails with 422."""
    data = setup_sprint_data
    proj_id = data["project"].id

    now = datetime.now(UTC)
    create_resp = client.post(
        f"/api/v1/projects/{proj_id}/sprints",
        json={
            "name": "Sprint To Update Dates",
            "start_date": now.isoformat(),
            "end_date": (now + timedelta(days=7)).isoformat(),
        },
        headers=_auth_header(data["member"]),
    )
    assert create_resp.status_code == 201
    sprint_id = create_resp.json()["id"]

    # Inverted dates on update
    patch_resp = client.patch(
        f"/api/v1/sprints/{sprint_id}",
        json={
            "start_date": (now + timedelta(days=14)).isoformat(),
            "end_date": (now + timedelta(days=7)).isoformat(),
        },
        headers=_auth_header(data["member"]),
    )
    assert patch_resp.status_code == 422


def test_only_one_active_sprint_enforced(client, setup_sprint_data):
    """Cannot create or activate more than one sprint simultaneously in a project."""
    data = setup_sprint_data
    proj_id = data["project"].id

    # 1. Create first active sprint -> succeeds
    resp1 = client.post(
        f"/api/v1/projects/{proj_id}/sprints",
        json={"name": "Sprint Active 1", "status": "active"},
        headers=_auth_header(data["admin"]),
    )
    assert resp1.status_code == 201
    sprint1_id = resp1.json()["id"]

    # 2. Try to create second active sprint -> 400 Bad Request
    resp2 = client.post(
        f"/api/v1/projects/{proj_id}/sprints",
        json={"name": "Sprint Active 2", "status": "active"},
        headers=_auth_header(data["admin"]),
    )
    assert resp2.status_code == 400
    assert "Only one active sprint" in resp2.json()["detail"]

    # 3. Create a planned sprint -> succeeds
    resp3 = client.post(
        f"/api/v1/projects/{proj_id}/sprints",
        json={"name": "Sprint Planned", "status": "planned"},
        headers=_auth_header(data["admin"]),
    )
    assert resp3.status_code == 201
    sprint3_id = resp3.json()["id"]

    # 4. Try to update the planned sprint to active while sprint 1 is active -> 400
    patch_resp = client.patch(
        f"/api/v1/sprints/{sprint3_id}",
        json={"status": "active"},
        headers=_auth_header(data["admin"]),
    )
    assert patch_resp.status_code == 400
    assert "Only one active sprint" in patch_resp.json()["detail"]

    # 5. Updating sprint 1 while it is active (e.g. rename) should succeed
    update_active_resp = client.patch(
        f"/api/v1/sprints/{sprint1_id}",
        json={"name": "Sprint Active 1 Renamed", "status": "active"},
        headers=_auth_header(data["admin"]),
    )
    assert update_active_resp.status_code == 200
    assert update_active_resp.json()["name"] == "Sprint Active 1 Renamed"

    # 6. Complete sprint 1 -> Now sprint 3 can be activated
    complete_resp = client.patch(
        f"/api/v1/sprints/{sprint1_id}",
        json={"status": "completed"},
        headers=_auth_header(data["admin"]),
    )
    assert complete_resp.status_code == 200

    activate_resp = client.patch(
        f"/api/v1/sprints/{sprint3_id}",
        json={"status": "active"},
        headers=_auth_header(data["admin"]),
    )
    assert activate_resp.status_code == 200
    assert activate_resp.json()["status"] == "active"


def test_sprint_read_and_list_with_filter(client, setup_sprint_data):
    """Can get sprint by ID and list sprints with optional status filtering."""
    data = setup_sprint_data
    proj_id = data["project"].id

    s1 = client.post(
        f"/api/v1/projects/{proj_id}/sprints",
        json={"name": "Sprint 1", "status": "planned"},
        headers=_auth_header(data["member"]),
    ).json()

    client.post(
        f"/api/v1/projects/{proj_id}/sprints",
        json={"name": "Sprint 2", "status": "active"},
        headers=_auth_header(data["member"]),
    )

    # Read by ID
    get_resp = client.get(
        f"/api/v1/sprints/{s1['id']}",
        headers=_auth_header(data["viewer"]),
    )
    assert get_resp.status_code == 200
    assert get_resp.json()["name"] == "Sprint 1"

    # List all sprints
    list_all = client.get(
        f"/api/v1/projects/{proj_id}/sprints",
        headers=_auth_header(data["viewer"]),
    )
    assert list_all.status_code == 200
    all_sprints = list_all.json()
    assert len(all_sprints) == 2

    # Filter by planned
    list_planned = client.get(
        f"/api/v1/projects/{proj_id}/sprints?status=planned",
        headers=_auth_header(data["viewer"]),
    )
    assert list_planned.status_code == 200
    assert len(list_planned.json()) == 1
    assert list_planned.json()[0]["name"] == "Sprint 1"

    # Filter by active
    list_active = client.get(
        f"/api/v1/projects/{proj_id}/sprints?status=active",
        headers=_auth_header(data["viewer"]),
    )
    assert list_active.status_code == 200
    assert len(list_active.json()) == 1
    assert list_active.json()[0]["name"] == "Sprint 2"


def test_delete_sprint_and_revert_assigned_issues(
    client, setup_sprint_data, db_session
):
    """Deleting a sprint soft-deletes it and resets assigned issues' sprint_id to None."""
    data = setup_sprint_data
    proj_id = data["project"].id

    create_resp = client.post(
        f"/api/v1/projects/{proj_id}/sprints",
        json={"name": "Sprint To Delete", "status": "planned"},
        headers=_auth_header(data["admin"]),
    )
    assert create_resp.status_code == 201
    sprint_id = uuid.UUID(create_resp.json()["id"])

    # Create an issue assigned to this sprint
    issue = Issue(
        project_id=proj_id,
        issue_number=101,
        title="Issue in Sprint",
        type=IssueType.TASK,
        status=IssueStatus.TODO,
        priority=IssuePriority.HIGH,
        reporter_id=data["admin"].id,
        sprint_id=sprint_id,
    )
    db_session.add(issue)
    db_session.commit()
    db_session.refresh(issue)
    assert issue.sprint_id == sprint_id

    # Delete sprint (requires ADMIN or higher)
    del_resp = client.delete(
        f"/api/v1/sprints/{sprint_id}",
        headers=_auth_header(data["admin"]),
    )
    assert del_resp.status_code == 204

    # Sprint is now 404
    get_del = client.get(
        f"/api/v1/sprints/{sprint_id}",
        headers=_auth_header(data["admin"]),
    )
    assert get_del.status_code == 404

    # Issue assigned to it has sprint_id reset to None
    db_session.refresh(issue)
    assert issue.sprint_id is None


def test_sprint_permissions(client, setup_sprint_data):
    """Test RBAC across sprint operations: VIEWER cannot create/update/delete, MEMBER cannot delete."""
    data = setup_sprint_data
    proj_id = data["project"].id

    # 1. VIEWER cannot create sprint -> 403
    create_viewer = client.post(
        f"/api/v1/projects/{proj_id}/sprints",
        json={"name": "Viewer Sprint"},
        headers=_auth_header(data["viewer"]),
    )
    assert create_viewer.status_code == 403

    # Create sprint as Admin
    sprint = client.post(
        f"/api/v1/projects/{proj_id}/sprints",
        json={"name": "Permissions Sprint"},
        headers=_auth_header(data["admin"]),
    ).json()
    sprint_id = sprint["id"]

    # 2. VIEWER cannot update sprint -> 403
    patch_viewer = client.patch(
        f"/api/v1/sprints/{sprint_id}",
        json={"name": "Updated by Viewer"},
        headers=_auth_header(data["viewer"]),
    )
    assert patch_viewer.status_code == 403

    # 3. MEMBER can update sprint -> 200
    patch_member = client.patch(
        f"/api/v1/sprints/{sprint_id}",
        json={"name": "Updated by Member"},
        headers=_auth_header(data["member"]),
    )
    assert patch_member.status_code == 200

    # 4. MEMBER cannot delete sprint -> 403
    del_member = client.delete(
        f"/api/v1/sprints/{sprint_id}",
        headers=_auth_header(data["member"]),
    )
    assert del_member.status_code == 403

    # 5. OUTSIDER gets 404
    get_outsider = client.get(
        f"/api/v1/sprints/{sprint_id}",
        headers=_auth_header(data["outsider"]),
    )
    assert get_outsider.status_code == 404

    # 6. Unauthenticated gets 401
    get_unauth = client.get(f"/api/v1/sprints/{sprint_id}")
    assert get_unauth.status_code == 401

    # 7. ADMIN can delete sprint -> 204
    del_admin = client.delete(
        f"/api/v1/sprints/{sprint_id}",
        headers=_auth_header(data["admin"]),
    )
    assert del_admin.status_code == 204
