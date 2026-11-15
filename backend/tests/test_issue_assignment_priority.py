import pytest
from fastapi.testclient import TestClient

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
def setup_issue_data(db_session):
    ws_owner = _create_user(db_session, "ws_owner@example.com", "Workspace Owner")
    proj_admin = _create_user(db_session, "proj_admin@example.com", "Project Admin")
    proj_member1 = _create_user(
        db_session, "proj_member1@example.com", "Project Member 1"
    )
    proj_member2 = _create_user(
        db_session, "proj_member2@example.com", "Project Member 2"
    )
    proj_viewer = _create_user(db_session, "proj_viewer@example.com", "Project Viewer")
    ws_only_user = _create_user(db_session, "ws_only@example.com", "Workspace Only")
    inactive_user = _create_user(
        db_session, "inactive@example.com", "Inactive User", is_active=False
    )
    outsider = _create_user(db_session, "outsider@example.com", "Outsider")

    ws = Workspace(name="Task Org", slug="task-org", owner_id=ws_owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.refresh(ws)

    db_session.add_all(
        [
            WorkspaceMember(
                workspace_id=ws.id, user_id=ws_owner.id, role=RoleType.OWNER
            ),
            WorkspaceMember(
                workspace_id=ws.id, user_id=proj_admin.id, role=RoleType.ADMIN
            ),
            WorkspaceMember(
                workspace_id=ws.id, user_id=proj_member1.id, role=RoleType.MEMBER
            ),
            WorkspaceMember(
                workspace_id=ws.id, user_id=proj_member2.id, role=RoleType.MEMBER
            ),
            WorkspaceMember(
                workspace_id=ws.id, user_id=proj_viewer.id, role=RoleType.VIEWER
            ),
            WorkspaceMember(
                workspace_id=ws.id, user_id=ws_only_user.id, role=RoleType.MEMBER
            ),
            WorkspaceMember(
                workspace_id=ws.id, user_id=inactive_user.id, role=RoleType.MEMBER
            ),
        ]
    )
    db_session.commit()

    proj = Project(name="Task Project", key="TSK", workspace_id=ws.id)
    db_session.add(proj)
    db_session.commit()
    db_session.refresh(proj)

    db_session.add_all(
        [
            ProjectMember(
                project_id=proj.id, user_id=proj_admin.id, role=RoleType.ADMIN
            ),
            ProjectMember(
                project_id=proj.id, user_id=proj_member1.id, role=RoleType.MEMBER
            ),
            ProjectMember(
                project_id=proj.id, user_id=proj_member2.id, role=RoleType.MEMBER
            ),
            ProjectMember(
                project_id=proj.id, user_id=proj_viewer.id, role=RoleType.VIEWER
            ),
            ProjectMember(
                project_id=proj.id, user_id=inactive_user.id, role=RoleType.MEMBER
            ),
        ]
    )
    db_session.commit()

    return {
        "workspace": ws,
        "project": proj,
        "ws_owner": ws_owner,
        "proj_admin": proj_admin,
        "proj_member1": proj_member1,
        "proj_member2": proj_member2,
        "proj_viewer": proj_viewer,
        "ws_only_user": ws_only_user,
        "inactive_user": inactive_user,
        "outsider": outsider,
    }


# ---------------------------------------------------------------------------
# Assignee Endpoint Tests (#95)
# ---------------------------------------------------------------------------
def test_assign_issue_to_project_member_success(client, setup_issue_data):
    """Member assigns an issue to another project member, activity is recorded."""
    proj = setup_issue_data["project"]
    m1 = setup_issue_data["proj_member1"]
    m2 = setup_issue_data["proj_member2"]

    # 1. Create issue without assignee
    resp_create = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m1),
        json={"title": "Unassigned Issue"},
    )
    assert resp_create.status_code == 201
    issue_id = resp_create.json()["id"]
    assert resp_create.json()["assignee_id"] is None

    # 2. Assign to m2
    resp_assign = client.patch(
        f"/api/v1/issues/{issue_id}/assignee",
        headers=_auth_header(m1),
        json={"assignee_id": str(m2.id)},
    )
    assert resp_assign.status_code == 200
    assert resp_assign.json()["assignee_id"] == str(m2.id)

    # 3. Verify activity record
    resp_act = client.get(
        f"/api/v1/issues/{issue_id}/activities",
        headers=_auth_header(m1),
    )
    assert resp_act.status_code == 200
    activities = resp_act.json()
    assert len(activities) >= 1
    assign_event = next(
        (a for a in activities if a["action"] == "assignee_changed"), None
    )
    assert assign_event is not None
    assert assign_event["actor_id"] == str(m1.id)
    assert assign_event["old_value"] is None
    assert assign_event["new_value"] == str(m2.id)


def test_unassign_issue(client, setup_issue_data):
    """Setting assignee_id to None unassigns the issue and logs activity."""
    proj = setup_issue_data["project"]
    m1 = setup_issue_data["proj_member1"]
    m2 = setup_issue_data["proj_member2"]

    resp_create = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m1),
        json={"title": "Pre-assigned Issue", "assignee_id": str(m2.id)},
    )
    issue_id = resp_create.json()["id"]

    # Unassign
    resp_unassign = client.patch(
        f"/api/v1/issues/{issue_id}/assignee",
        headers=_auth_header(m1),
        json={"assignee_id": None},
    )
    assert resp_unassign.status_code == 200
    assert resp_unassign.json()["assignee_id"] is None

    # Activity recorded
    resp_act = client.get(
        f"/api/v1/issues/{issue_id}/activities",
        headers=_auth_header(m1),
    )
    assert resp_act.status_code == 200
    acts = [a for a in resp_act.json() if a["action"] == "assignee_changed"]
    assert len(acts) >= 1
    last_act = acts[-1]
    assert last_act["old_value"] == str(m2.id)
    assert last_act["new_value"] is None


def test_assign_issue_non_member_rejected(client, setup_issue_data):
    """Assigning user outside project returns 400 Bad Request."""
    proj = setup_issue_data["project"]
    m1 = setup_issue_data["proj_member1"]
    ws_only = setup_issue_data["ws_only_user"]
    outsider = setup_issue_data["outsider"]

    resp_create = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m1),
        json={"title": "Target Issue"},
    )
    issue_id = resp_create.json()["id"]

    # Workspace user but not project member -> 400
    resp_ws = client.patch(
        f"/api/v1/issues/{issue_id}/assignee",
        headers=_auth_header(m1),
        json={"assignee_id": str(ws_only.id)},
    )
    assert resp_ws.status_code == 400
    assert "Assignee must be a member of the project" in resp_ws.json()["detail"]

    # Complete outsider -> 400
    resp_out = client.patch(
        f"/api/v1/issues/{issue_id}/assignee",
        headers=_auth_header(m1),
        json={"assignee_id": str(outsider.id)},
    )
    assert resp_out.status_code == 400
    assert "Assignee must be a member of the project" in resp_out.json()["detail"]


def test_assign_issue_inactive_or_nonexistent_user_rejected(client, setup_issue_data):
    """Assigning inactive or nonexistent user returns 400 Bad Request."""
    proj = setup_issue_data["project"]
    m1 = setup_issue_data["proj_member1"]
    inactive = setup_issue_data["inactive_user"]

    resp_create = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m1),
        json={"title": "Inactive Target"},
    )
    issue_id = resp_create.json()["id"]

    # Inactive user -> 400
    resp_in = client.patch(
        f"/api/v1/issues/{issue_id}/assignee",
        headers=_auth_header(m1),
        json={"assignee_id": str(inactive.id)},
    )
    assert resp_in.status_code == 400
    assert "Assignee not found or inactive" in resp_in.json()["detail"]

    # Non-existent UUID -> 400
    resp_fake = client.patch(
        f"/api/v1/issues/{issue_id}/assignee",
        headers=_auth_header(m1),
        json={"assignee_id": "00000000-0000-0000-0000-000000000000"},
    )
    assert resp_fake.status_code == 400
    assert "Assignee not found or inactive" in resp_fake.json()["detail"]


def test_assign_issue_permission_enforcement(client, setup_issue_data):
    """Viewer cannot assign issues (403), outsider gets 404."""
    proj = setup_issue_data["project"]
    m1 = setup_issue_data["proj_member1"]
    viewer = setup_issue_data["proj_viewer"]
    outsider = setup_issue_data["outsider"]

    resp_create = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m1),
        json={"title": "Permission Target"},
    )
    issue_id = resp_create.json()["id"]

    # Viewer -> 403
    resp_v = client.patch(
        f"/api/v1/issues/{issue_id}/assignee",
        headers=_auth_header(viewer),
        json={"assignee_id": str(m1.id)},
    )
    assert resp_v.status_code == 403

    # Outsider -> 404
    resp_o = client.patch(
        f"/api/v1/issues/{issue_id}/assignee",
        headers=_auth_header(outsider),
        json={"assignee_id": str(m1.id)},
    )
    assert resp_o.status_code == 404


# ---------------------------------------------------------------------------
# Priority Endpoint Tests (#95)
# ---------------------------------------------------------------------------
def test_change_issue_priority_success(client, setup_issue_data):
    """Change priority of an issue and record activity."""
    proj = setup_issue_data["project"]
    m1 = setup_issue_data["proj_member1"]

    resp_create = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m1),
        json={"title": "Priority Target", "priority": "medium"},
    )
    issue_id = resp_create.json()["id"]
    assert resp_create.json()["priority"] == "medium"

    # Change to urgent
    resp_up = client.patch(
        f"/api/v1/issues/{issue_id}/priority",
        headers=_auth_header(m1),
        json={"priority": "urgent"},
    )
    assert resp_up.status_code == 200
    assert resp_up.json()["priority"] == "urgent"

    # Check activity record
    resp_act = client.get(
        f"/api/v1/issues/{issue_id}/activities",
        headers=_auth_header(m1),
    )
    assert resp_act.status_code == 200
    acts = [a for a in resp_act.json() if a["action"] == "priority_changed"]
    assert len(acts) >= 1
    p_act = acts[-1]
    assert p_act["old_value"] == "medium"
    assert p_act["new_value"] == "urgent"
    assert p_act["actor_id"] == str(m1.id)


def test_change_issue_priority_invalid_value(client, setup_issue_data):
    """Invalid priority value raises 422 Unprocessable Entity."""
    proj = setup_issue_data["project"]
    m1 = setup_issue_data["proj_member1"]

    resp_create = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m1),
        json={"title": "Invalid Priority Target"},
    )
    issue_id = resp_create.json()["id"]

    resp_bad = client.patch(
        f"/api/v1/issues/{issue_id}/priority",
        headers=_auth_header(m1),
        json={"priority": "super_critical"},
    )
    assert resp_bad.status_code == 422


def test_change_issue_priority_permissions(client, setup_issue_data):
    """Viewer cannot change priority (403), outsider gets 404."""
    proj = setup_issue_data["project"]
    m1 = setup_issue_data["proj_member1"]
    viewer = setup_issue_data["proj_viewer"]
    outsider = setup_issue_data["outsider"]

    resp_create = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m1),
        json={"title": "Priority Permission Target"},
    )
    issue_id = resp_create.json()["id"]

    # Viewer -> 403
    resp_v = client.patch(
        f"/api/v1/issues/{issue_id}/priority",
        headers=_auth_header(viewer),
        json={"priority": "high"},
    )
    assert resp_v.status_code == 403

    # Outsider -> 404
    resp_o = client.patch(
        f"/api/v1/issues/{issue_id}/priority",
        headers=_auth_header(outsider),
        json={"priority": "high"},
    )
    assert resp_o.status_code == 404


# ---------------------------------------------------------------------------
# General Update Activity Recording Test
# ---------------------------------------------------------------------------
def test_general_update_records_activity(client, setup_issue_data):
    """PATCH /api/v1/issues/{id} also records activity when assignee/priority change."""
    proj = setup_issue_data["project"]
    m1 = setup_issue_data["proj_member1"]
    m2 = setup_issue_data["proj_member2"]

    resp_create = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m1),
        json={"title": "General Update Issue", "priority": "low"},
    )
    issue_id = resp_create.json()["id"]

    # General update changing both assignee and priority
    resp_patch = client.patch(
        f"/api/v1/issues/{issue_id}",
        headers=_auth_header(m1),
        json={
            "assignee_id": str(m2.id),
            "priority": "high",
            "description": "Added details",
        },
    )
    assert resp_patch.status_code == 200

    # Verify both activities logged
    resp_act = client.get(
        f"/api/v1/issues/{issue_id}/activities",
        headers=_auth_header(m1),
    )
    assert resp_act.status_code == 200
    actions = {a["action"] for a in resp_act.json()}
    assert "assignee_changed" in actions
    assert "priority_changed" in actions
