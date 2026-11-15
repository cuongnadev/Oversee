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
def setup_issue_data(db_session):
    ws_owner = _create_user(db_session, "ws_owner@example.com", "Workspace Owner")
    proj_admin = _create_user(db_session, "proj_admin@example.com", "Project Admin")
    proj_member = _create_user(db_session, "proj_member@example.com", "Project Member")
    proj_viewer = _create_user(db_session, "proj_viewer@example.com", "Project Viewer")
    outsider = _create_user(db_session, "outsider@example.com", "Outsider")

    ws = Workspace(name="Flow Org", slug="flow-org", owner_id=ws_owner.id)
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
                workspace_id=ws.id, user_id=proj_member.id, role=RoleType.MEMBER
            ),
            WorkspaceMember(
                workspace_id=ws.id, user_id=proj_viewer.id, role=RoleType.VIEWER
            ),
        ]
    )
    db_session.commit()

    proj = Project(name="Flow Project", key="FLW", workspace_id=ws.id)
    db_session.add(proj)
    db_session.commit()
    db_session.refresh(proj)

    db_session.add_all(
        [
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
        "workspace": ws,
        "project": proj,
        "proj_member": proj_member,
        "proj_viewer": proj_viewer,
        "outsider": outsider,
    }


# ---------------------------------------------------------------------------
# Valid Transitions Lifecycle Tests (#96)
# ---------------------------------------------------------------------------
def test_valid_status_transition_lifecycle(client, setup_issue_data):
    """
    Test complete valid forward workflow:
    BACKLOG -> TODO -> IN_PROGRESS -> IN_REVIEW -> DONE -> TODO (reopened)
    """
    proj = setup_issue_data["project"]
    m = setup_issue_data["proj_member"]

    # 1. Create issue (defaults to BACKLOG)
    resp_create = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m),
        json={"title": "Workflow Issue"},
    )
    assert resp_create.status_code == 201
    issue_id = resp_create.json()["id"]
    assert resp_create.json()["status"] == "backlog"

    # 2. BACKLOG -> TODO
    resp_todo = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "todo"},
    )
    assert resp_todo.status_code == 200
    assert resp_todo.json()["status"] == "todo"

    # 3. TODO -> IN_PROGRESS
    resp_prog = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "in_progress"},
    )
    assert resp_prog.status_code == 200
    assert resp_prog.json()["status"] == "in_progress"

    # 4. IN_PROGRESS -> IN_REVIEW
    resp_rev = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "in_review"},
    )
    assert resp_rev.status_code == 200
    assert resp_rev.json()["status"] == "in_review"

    # 5. IN_REVIEW -> DONE
    resp_done = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "done"},
    )
    assert resp_done.status_code == 200
    assert resp_done.json()["status"] == "done"

    # 6. Reopen: DONE -> TODO
    resp_reopen = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "todo"},
    )
    assert resp_reopen.status_code == 200
    assert resp_reopen.json()["status"] == "todo"

    # 7. Verify activity log
    resp_act = client.get(
        f"/api/v1/issues/{issue_id}/activities",
        headers=_auth_header(m),
    )
    assert resp_act.status_code == 200
    status_acts = [a for a in resp_act.json() if a["action"] == "status_changed"]
    assert len(status_acts) == 5
    assert status_acts[0]["old_value"] == "backlog"
    assert status_acts[0]["new_value"] == "todo"
    assert status_acts[-1]["old_value"] == "done"
    assert status_acts[-1]["new_value"] == "todo"


def test_valid_backward_transitions(client, setup_issue_data):
    """Test valid backward transitions: TODO -> BACKLOG, IN_REVIEW -> IN_PROGRESS, IN_PROGRESS -> TODO."""
    proj = setup_issue_data["project"]
    m = setup_issue_data["proj_member"]

    resp = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m),
        json={"title": "Backward Test Issue"},
    )
    issue_id = resp.json()["id"]

    # BACKLOG -> TODO
    client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "todo"},
    )

    # TODO -> BACKLOG (pull back)
    resp_back = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "backlog"},
    )
    assert resp_back.status_code == 200
    assert resp_back.json()["status"] == "backlog"

    # BACKLOG -> TODO -> IN_PROGRESS -> IN_REVIEW
    client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "todo"},
    )
    client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "in_progress"},
    )
    client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "in_review"},
    )

    # IN_REVIEW -> IN_PROGRESS (rework)
    resp_rework = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "in_progress"},
    )
    assert resp_rework.status_code == 200
    assert resp_rework.json()["status"] == "in_progress"

    # IN_PROGRESS -> TODO (paused)
    resp_pause = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "todo"},
    )
    assert resp_pause.status_code == 200
    assert resp_pause.json()["status"] == "todo"


def test_same_status_transition_idempotent(client, setup_issue_data):
    """Transitioning to the current status is a valid no-op."""
    proj = setup_issue_data["project"]
    m = setup_issue_data["proj_member"]

    resp = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m),
        json={"title": "No-op Test"},
    )
    issue_id = resp.json()["id"]

    resp_noop = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "backlog"},
    )
    assert resp_noop.status_code == 200
    assert resp_noop.json()["status"] == "backlog"


# ---------------------------------------------------------------------------
# Invalid Transition Tests (422 Unprocessable Content) (#96)
# ---------------------------------------------------------------------------
def test_invalid_transitions_from_backlog_return_422(client, setup_issue_data):
    """BACKLOG cannot jump straight to IN_PROGRESS, IN_REVIEW, or DONE (422)."""
    proj = setup_issue_data["project"]
    m = setup_issue_data["proj_member"]

    resp = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m),
        json={"title": "Backlog Jump Test"},
    )
    issue_id = resp.json()["id"]

    # BACKLOG -> IN_PROGRESS -> 422
    resp_prog = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "in_progress"},
    )
    assert resp_prog.status_code == 422
    assert "Invalid status transition" in resp_prog.json()["detail"]

    # BACKLOG -> IN_REVIEW -> 422
    resp_rev = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "in_review"},
    )
    assert resp_rev.status_code == 422

    # BACKLOG -> DONE -> 422
    resp_done = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "done"},
    )
    assert resp_done.status_code == 422


def test_invalid_transitions_from_todo_return_422(client, setup_issue_data):
    """TODO cannot jump straight to IN_REVIEW or DONE (422)."""
    proj = setup_issue_data["project"]
    m = setup_issue_data["proj_member"]

    resp = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m),
        json={"title": "Todo Jump Test"},
    )
    issue_id = resp.json()["id"]

    client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "todo"},
    )

    # TODO -> IN_REVIEW -> 422
    assert (
        client.patch(
            f"/api/v1/issues/{issue_id}/status",
            headers=_auth_header(m),
            json={"status": "in_review"},
        ).status_code
        == 422
    )

    # TODO -> DONE -> 422
    assert (
        client.patch(
            f"/api/v1/issues/{issue_id}/status",
            headers=_auth_header(m),
            json={"status": "done"},
        ).status_code
        == 422
    )


def test_invalid_transitions_from_in_progress_return_422(client, setup_issue_data):
    """IN_PROGRESS cannot jump to BACKLOG or straight to DONE without review (422)."""
    proj = setup_issue_data["project"]
    m = setup_issue_data["proj_member"]

    resp = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m),
        json={"title": "In Progress Jump Test"},
    )
    issue_id = resp.json()["id"]

    client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "todo"},
    )
    client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "in_progress"},
    )

    # IN_PROGRESS -> BACKLOG -> 422
    assert (
        client.patch(
            f"/api/v1/issues/{issue_id}/status",
            headers=_auth_header(m),
            json={"status": "backlog"},
        ).status_code
        == 422
    )

    # IN_PROGRESS -> DONE -> 422
    assert (
        client.patch(
            f"/api/v1/issues/{issue_id}/status",
            headers=_auth_header(m),
            json={"status": "done"},
        ).status_code
        == 422
    )


def test_invalid_transitions_from_in_review_return_422(client, setup_issue_data):
    """IN_REVIEW cannot jump directly to BACKLOG or TODO (422)."""
    proj = setup_issue_data["project"]
    m = setup_issue_data["proj_member"]

    resp = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m),
        json={"title": "In Review Jump Test"},
    )
    issue_id = resp.json()["id"]

    client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "todo"},
    )
    client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "in_progress"},
    )
    client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(m),
        json={"status": "in_review"},
    )

    # IN_REVIEW -> BACKLOG -> 422
    assert (
        client.patch(
            f"/api/v1/issues/{issue_id}/status",
            headers=_auth_header(m),
            json={"status": "backlog"},
        ).status_code
        == 422
    )

    # IN_REVIEW -> TODO -> 422
    assert (
        client.patch(
            f"/api/v1/issues/{issue_id}/status",
            headers=_auth_header(m),
            json={"status": "todo"},
        ).status_code
        == 422
    )


def test_general_patch_also_validates_status_transitions(client, setup_issue_data):
    """General PATCH /api/v1/issues/{id} also enforces transition rules (422)."""
    proj = setup_issue_data["project"]
    m = setup_issue_data["proj_member"]

    resp = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m),
        json={"title": "General Patch Transition"},
    )
    issue_id = resp.json()["id"]

    # Try invalid jump from BACKLOG to DONE via general update -> 422
    resp_invalid = client.patch(
        f"/api/v1/issues/{issue_id}",
        headers=_auth_header(m),
        json={"status": "done"},
    )
    assert resp_invalid.status_code == 422
    assert "Invalid status transition" in resp_invalid.json()["detail"]


# ---------------------------------------------------------------------------
# Permissions Tests (#96)
# ---------------------------------------------------------------------------
def test_change_issue_status_permissions(client, setup_issue_data):
    """Viewer cannot change issue status (403), outsider gets 404."""
    proj = setup_issue_data["project"]
    m = setup_issue_data["proj_member"]
    viewer = setup_issue_data["proj_viewer"]
    outsider = setup_issue_data["outsider"]

    resp = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(m),
        json={"title": "Permission Status Test"},
    )
    issue_id = resp.json()["id"]

    # Viewer -> 403
    resp_v = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(viewer),
        json={"status": "todo"},
    )
    assert resp_v.status_code == 403

    # Outsider -> 404
    resp_o = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        headers=_auth_header(outsider),
        json={"status": "todo"},
    )
    assert resp_o.status_code == 404
