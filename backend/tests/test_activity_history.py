import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.core.security import create_access_token, hash_password
from app.db.session import get_db
from app.main import app
from app.models.activity import Activity
from app.models.enums import (
    RoleType,
)
from app.models.membership import ProjectMember, WorkspaceMember
from app.models.project import Project
from app.models.sprint import Sprint
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
def setup_activity_data(db_session):
    ws_owner = _create_user(db_session, "ws_owner@example.com", "Workspace Owner")
    proj_admin = _create_user(db_session, "admin@example.com", "Project Admin")
    m1 = _create_user(db_session, "member1@example.com", "Member 1")
    m2 = _create_user(db_session, "member2@example.com", "Member 2")
    viewer = _create_user(db_session, "viewer@example.com", "Viewer")
    outsider = _create_user(db_session, "outsider@example.com", "Outsider")

    ws = Workspace(name="Activity Workspace", slug="activity-ws", owner_id=ws_owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.refresh(ws)

    for u, r in [
        (ws_owner, RoleType.OWNER),
        (proj_admin, RoleType.ADMIN),
        (m1, RoleType.MEMBER),
        (m2, RoleType.MEMBER),
        (viewer, RoleType.VIEWER),
    ]:
        db_session.add(WorkspaceMember(workspace_id=ws.id, user_id=u.id, role=r))
    db_session.commit()

    proj = Project(
        workspace_id=ws.id,
        name="Activity Project",
        key="ACT",
    )
    db_session.add(proj)
    db_session.commit()
    db_session.refresh(proj)

    for u, r in [
        (proj_admin, RoleType.ADMIN),
        (m1, RoleType.MEMBER),
        (m2, RoleType.MEMBER),
        (viewer, RoleType.VIEWER),
    ]:
        db_session.add(ProjectMember(project_id=proj.id, user_id=u.id, role=r))
    db_session.commit()

    sprint = Sprint(project_id=proj.id, name="Sprint 1")
    db_session.add(sprint)
    db_session.commit()
    db_session.refresh(sprint)

    return {
        "admin": proj_admin,
        "member1": m1,
        "member2": m2,
        "viewer": viewer,
        "outsider": outsider,
        "project": proj,
        "sprint": sprint,
    }


# ---------------------------------------------------------------------------
# Test Cases
# ---------------------------------------------------------------------------
def test_activity_logged_on_issue_creation(client, setup_activity_data, db_session):
    """Creating an issue records an activity event and persists to database."""
    data = setup_activity_data
    proj_id = data["project"].id

    resp = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Task for Activity Log", "type": "task", "status": "todo"},
        headers=_auth_header(data["member1"]),
    )
    assert resp.status_code == 201
    issue_id = resp.json()["id"]

    # Verify activity endpoint
    resp_act = client.get(
        f"/api/v1/issues/{issue_id}/activities",
        headers=_auth_header(data["member1"]),
    )
    assert resp_act.status_code == 200
    acts = resp_act.json()
    assert len(acts) >= 1
    create_act = next((a for a in acts if a["action"] == "issue_created"), None)
    assert create_act is not None
    assert create_act["actor_id"] == str(data["member1"].id)
    assert create_act["new_value"] == "Task for Activity Log"

    # Verify directly in database table
    db_acts = list(
        db_session.scalars(
            select(Activity).where(Activity.issue_id == uuid.UUID(issue_id))
        ).all()
    )
    assert len(db_acts) >= 1


def test_activity_logged_on_status_change(client, setup_activity_data, db_session):
    """Changing issue status records status_changed with before and after states."""
    data = setup_activity_data
    proj_id = data["project"].id

    create_resp = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Status Workflow Issue", "status": "todo"},
        headers=_auth_header(data["member1"]),
    )
    assert create_resp.status_code == 201
    issue_id = create_resp.json()["id"]

    # Transition: TODO -> IN_PROGRESS
    patch_resp = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        json={"status": "in_progress"},
        headers=_auth_header(data["member1"]),
    )
    assert patch_resp.status_code == 200

    # Transition: IN_PROGRESS -> IN_REVIEW
    patch_resp2 = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        json={"status": "in_review"},
        headers=_auth_header(data["member1"]),
    )
    assert patch_resp2.status_code == 200

    # Transition: IN_REVIEW -> DONE
    patch_resp3 = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        json={"status": "done"},
        headers=_auth_header(data["member1"]),
    )
    assert patch_resp3.status_code == 200

    # Fetch activities
    act_resp = client.get(
        f"/api/v1/issues/{issue_id}/activities",
        headers=_auth_header(data["viewer"]),
    )
    assert act_resp.status_code == 200
    acts = [a for a in act_resp.json() if a["action"] == "status_changed"]
    assert len(acts) == 3
    assert acts[0]["old_value"] == "todo"
    assert acts[0]["new_value"] == "in_progress"
    assert acts[1]["old_value"] == "in_progress"
    assert acts[1]["new_value"] == "in_review"
    assert acts[2]["old_value"] == "in_review"
    assert acts[2]["new_value"] == "done"


def test_activity_logged_on_assignee_change(client, setup_activity_data):
    """Assigning and unassigning an issue records assignee_changed events."""
    data = setup_activity_data
    proj_id = data["project"].id
    m1 = data["member1"]
    m2 = data["member2"]

    create_resp = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Assignment Issue", "status": "todo"},
        headers=_auth_header(m1),
    )
    issue_id = create_resp.json()["id"]

    # Assign to m2
    assign_resp = client.patch(
        f"/api/v1/issues/{issue_id}/assignee",
        json={"assignee_id": str(m2.id)},
        headers=_auth_header(m1),
    )
    assert assign_resp.status_code == 200

    # Unassign
    unassign_resp = client.patch(
        f"/api/v1/issues/{issue_id}/assignee",
        json={"assignee_id": None},
        headers=_auth_header(m1),
    )
    assert unassign_resp.status_code == 200

    # Check activities
    act_resp = client.get(
        f"/api/v1/issues/{issue_id}/activities",
        headers=_auth_header(data["viewer"]),
    )
    acts = [a for a in act_resp.json() if a["action"] == "assignee_changed"]
    assert len(acts) == 2
    assert acts[0]["old_value"] is None
    assert acts[0]["new_value"] == str(m2.id)
    assert acts[1]["old_value"] == str(m2.id)
    assert acts[1]["new_value"] is None


def test_activity_logged_on_priority_change(client, setup_activity_data):
    """Changing priority records priority_changed events."""
    data = setup_activity_data
    proj_id = data["project"].id
    m1 = data["member1"]

    create_resp = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Priority Issue", "priority": "low"},
        headers=_auth_header(m1),
    )
    issue_id = create_resp.json()["id"]

    # Change to urgent
    p_resp = client.patch(
        f"/api/v1/issues/{issue_id}/priority",
        json={"priority": "urgent"},
        headers=_auth_header(m1),
    )
    assert p_resp.status_code == 200

    act_resp = client.get(
        f"/api/v1/issues/{issue_id}/activities",
        headers=_auth_header(data["viewer"]),
    )
    acts = [a for a in act_resp.json() if a["action"] == "priority_changed"]
    assert len(acts) == 1
    assert acts[0]["old_value"] == "low"
    assert acts[0]["new_value"] == "urgent"


def test_activity_logged_on_batch_update(client, setup_activity_data):
    """Updating multiple fields in PATCH /issues/{id} records distinct events for each field changed."""
    data = setup_activity_data
    proj_id = data["project"].id
    m1 = data["member1"]
    m2 = data["member2"]

    create_resp = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Initial Title", "status": "todo", "priority": "medium"},
        headers=_auth_header(m1),
    )
    issue_id = create_resp.json()["id"]

    # Multi-field update: title, status, priority, assignee
    patch_resp = client.patch(
        f"/api/v1/issues/{issue_id}",
        json={
            "title": "Updated Title",
            "status": "in_progress",
            "priority": "high",
            "assignee_id": str(m2.id),
        },
        headers=_auth_header(m1),
    )
    assert patch_resp.status_code == 200

    act_resp = client.get(
        f"/api/v1/issues/{issue_id}/activities",
        headers=_auth_header(data["viewer"]),
    )
    actions = {a["action"]: a for a in act_resp.json()}
    assert "title_changed" in actions
    assert actions["title_changed"]["old_value"] == "Initial Title"
    assert actions["title_changed"]["new_value"] == "Updated Title"

    assert "status_changed" in actions
    assert actions["status_changed"]["old_value"] == "todo"
    assert actions["status_changed"]["new_value"] == "in_progress"

    assert "priority_changed" in actions
    assert actions["priority_changed"]["old_value"] == "medium"
    assert actions["priority_changed"]["new_value"] == "high"

    assert "assignee_changed" in actions
    assert actions["assignee_changed"]["new_value"] == str(m2.id)


def test_activity_endpoint_alias_and_permissions(client, setup_activity_data):
    """RBAC checks: VIEWER can view, OUTSIDER gets 404, unauth gets 401."""
    data = setup_activity_data
    proj_id = data["project"].id

    create_resp = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Perm Issue"},
        headers=_auth_header(data["member1"]),
    )
    issue_id = create_resp.json()["id"]

    # 1. Singular endpoint alias works
    resp_alias = client.get(
        f"/api/v1/issues/{issue_id}/activity",
        headers=_auth_header(data["viewer"]),
    )
    assert resp_alias.status_code == 200
    assert len(resp_alias.json()) >= 1

    # 2. OUTSIDER gets 404
    resp_out = client.get(
        f"/api/v1/issues/{issue_id}/activities",
        headers=_auth_header(data["outsider"]),
    )
    assert resp_out.status_code == 404

    # 3. Unauthenticated gets 401
    resp_unauth = client.get(f"/api/v1/issues/{issue_id}/activities")
    assert resp_unauth.status_code == 401
