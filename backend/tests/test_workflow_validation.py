import pytest
from fastapi.testclient import TestClient

from app.core.security import create_access_token, hash_password
from app.db.session import get_db
from app.main import app
from app.models.enums import (
    RoleType,
    SprintStatus,
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
def setup_workflow_data(db_session):
    ws_owner = _create_user(db_session, "ws_owner@example.com", "Workspace Owner")
    proj_admin = _create_user(db_session, "admin@example.com", "Project Admin")
    m1 = _create_user(db_session, "member1@example.com", "Member 1")
    viewer = _create_user(db_session, "viewer@example.com", "Viewer")
    outsider = _create_user(db_session, "outsider@example.com", "Outsider")

    ws = Workspace(name="Workflow WS", slug="workflow-ws", owner_id=ws_owner.id)
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
        name="Workflow Project",
        key="WF",
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

    # Create sprints in different states
    sprint_planned = Sprint(
        project_id=proj.id, name="Planned Sprint", status=SprintStatus.PLANNED
    )
    sprint_active = Sprint(
        project_id=proj.id, name="Active Sprint", status=SprintStatus.ACTIVE
    )
    sprint_completed = Sprint(
        project_id=proj.id, name="Completed Sprint", status=SprintStatus.COMPLETED
    )
    sprint_closed = Sprint(
        project_id=proj.id, name="Closed Sprint", status=SprintStatus.CLOSED
    )
    db_session.add_all([sprint_planned, sprint_active, sprint_completed, sprint_closed])
    db_session.commit()
    for s in [sprint_planned, sprint_active, sprint_completed, sprint_closed]:
        db_session.refresh(s)

    return {
        "admin": proj_admin,
        "member": m1,
        "viewer": viewer,
        "outsider": outsider,
        "project": proj,
        "sprint_planned": sprint_planned,
        "sprint_active": sprint_active,
        "sprint_completed": sprint_completed,
        "sprint_closed": sprint_closed,
    }


# ---------------------------------------------------------------------------
# Test Cases: Rule 1 - Cannot Done when open sub-issues exist
# ---------------------------------------------------------------------------
def test_cannot_mark_issue_done_with_open_sub_issues(client, setup_workflow_data):
    """Parent issue cannot be resolved to DONE if it has active open sub-issues."""
    data = setup_workflow_data
    proj_id = data["project"].id
    member = data["member"]

    # 1. Create parent issue
    resp_parent = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Parent Feature", "type": "story", "status": "todo"},
        headers=_auth_header(member),
    )
    assert resp_parent.status_code == 201
    parent_id = resp_parent.json()["id"]

    # 2. Create subtask under parent
    resp_sub = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={
            "title": "Subtask 1",
            "type": "subtask",
            "status": "todo",
            "parent_id": parent_id,
        },
        headers=_auth_header(member),
    )
    assert resp_sub.status_code == 201

    # 3. Advance parent from TODO -> IN_PROGRESS -> IN_REVIEW
    client.patch(
        f"/api/v1/issues/{parent_id}/status",
        json={"status": "in_progress"},
        headers=_auth_header(member),
    )
    client.patch(
        f"/api/v1/issues/{parent_id}/status",
        json={"status": "in_review"},
        headers=_auth_header(member),
    )

    # 4. Attempt to transition parent from IN_REVIEW to DONE while subtask is still TODO
    resp_done = client.patch(
        f"/api/v1/issues/{parent_id}/status",
        json={"status": "done"},
        headers=_auth_header(member),
    )
    assert resp_done.status_code == 400
    assert "Cannot mark issue as done" in resp_done.json()["detail"]
    assert "sub-issue(s) remain open" in resp_done.json()["detail"]


def test_can_mark_issue_done_when_all_sub_issues_resolved(client, setup_workflow_data):
    """Parent issue can transition to DONE once all child sub-issues are DONE or CANCELED."""
    data = setup_workflow_data
    proj_id = data["project"].id
    member = data["member"]

    # Create parent
    resp_p = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Parent Task", "status": "todo"},
        headers=_auth_header(member),
    )
    parent_id = resp_p.json()["id"]

    # Create two subtasks
    resp_s1 = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={
            "title": "Sub 1",
            "type": "subtask",
            "status": "todo",
            "parent_id": parent_id,
        },
        headers=_auth_header(member),
    )
    s1_id = resp_s1.json()["id"]

    resp_s2 = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={
            "title": "Sub 2",
            "type": "subtask",
            "status": "todo",
            "parent_id": parent_id,
        },
        headers=_auth_header(member),
    )
    s2_id = resp_s2.json()["id"]

    # Resolve subtask 1: TODO -> IN_PROGRESS -> IN_REVIEW -> DONE
    client.patch(
        f"/api/v1/issues/{s1_id}/status",
        json={"status": "in_progress"},
        headers=_auth_header(member),
    )
    client.patch(
        f"/api/v1/issues/{s1_id}/status",
        json={"status": "in_review"},
        headers=_auth_header(member),
    )
    client.patch(
        f"/api/v1/issues/{s1_id}/status",
        json={"status": "done"},
        headers=_auth_header(member),
    )

    # Cancel subtask 2: TODO -> CANCELED
    client.patch(
        f"/api/v1/issues/{s2_id}/status",
        json={"status": "canceled"},
        headers=_auth_header(member),
    )

    # Advance parent: TODO -> IN_PROGRESS -> IN_REVIEW -> DONE
    client.patch(
        f"/api/v1/issues/{parent_id}/status",
        json={"status": "in_progress"},
        headers=_auth_header(member),
    )
    client.patch(
        f"/api/v1/issues/{parent_id}/status",
        json={"status": "in_review"},
        headers=_auth_header(member),
    )
    resp_done = client.patch(
        f"/api/v1/issues/{parent_id}/status",
        json={"status": "done"},
        headers=_auth_header(member),
    )
    assert resp_done.status_code == 200
    assert resp_done.json()["status"] == "done"


def test_can_mark_issue_done_with_open_sub_issues_when_configured(
    client, setup_workflow_data
):
    """Parent issue can transition to DONE with open sub-issues if allow_open_subissues=True is configured."""
    data = setup_workflow_data
    proj_id = data["project"].id
    member = data["member"]

    # Create parent and open subtask
    resp_p = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Parent Configurable", "status": "todo"},
        headers=_auth_header(member),
    )
    parent_id = resp_p.json()["id"]

    client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={
            "title": "Open Subtask",
            "type": "subtask",
            "status": "todo",
            "parent_id": parent_id,
        },
        headers=_auth_header(member),
    )

    # Advance parent: TODO -> IN_PROGRESS -> IN_REVIEW
    client.patch(
        f"/api/v1/issues/{parent_id}/status",
        json={"status": "in_progress"},
        headers=_auth_header(member),
    )
    client.patch(
        f"/api/v1/issues/{parent_id}/status",
        json={"status": "in_review"},
        headers=_auth_header(member),
    )

    # 1. Using JSON payload field `allow_open_subissues=True`
    resp_body_override = client.patch(
        f"/api/v1/issues/{parent_id}/status",
        json={"status": "done", "allow_open_subissues": True},
        headers=_auth_header(member),
    )
    assert resp_body_override.status_code == 200
    assert resp_body_override.json()["status"] == "done"

    # Transition parent back to IN_PROGRESS -> IN_REVIEW
    client.patch(
        f"/api/v1/issues/{parent_id}/status",
        json={"status": "in_progress"},
        headers=_auth_header(member),
    )
    client.patch(
        f"/api/v1/issues/{parent_id}/status",
        json={"status": "in_review"},
        headers=_auth_header(member),
    )

    # 2. Using Query parameter `?allow_open_subissues=true`
    resp_query_override = client.patch(
        f"/api/v1/issues/{parent_id}/status?allow_open_subissues=true",
        json={"status": "done"},
        headers=_auth_header(member),
    )
    assert resp_query_override.status_code == 200
    assert resp_query_override.json()["status"] == "done"


def test_batch_update_validates_open_sub_issues(client, setup_workflow_data):
    """PATCH /issues/{id} batch update validates open sub-issues when updating status to DONE."""
    data = setup_workflow_data
    proj_id = data["project"].id
    member = data["member"]

    # Create parent and open subtask
    resp_p = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Batch Parent", "status": "todo"},
        headers=_auth_header(member),
    )
    parent_id = resp_p.json()["id"]

    client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={
            "title": "Pending Subtask",
            "type": "subtask",
            "status": "todo",
            "parent_id": parent_id,
        },
        headers=_auth_header(member),
    )

    # Advance parent to IN_REVIEW
    client.patch(
        f"/api/v1/issues/{parent_id}/status",
        json={"status": "in_progress"},
        headers=_auth_header(member),
    )
    client.patch(
        f"/api/v1/issues/{parent_id}/status",
        json={"status": "in_review"},
        headers=_auth_header(member),
    )

    # Attempt batch patch to DONE without override -> 400
    resp_fail = client.patch(
        f"/api/v1/issues/{parent_id}",
        json={"status": "done"},
        headers=_auth_header(member),
    )
    assert resp_fail.status_code == 400
    assert "Cannot mark issue as done" in resp_fail.json()["detail"]

    # Batch patch with allow_open_subissues=True -> 200
    resp_ok = client.patch(
        f"/api/v1/issues/{parent_id}",
        json={"status": "done", "allow_open_subissues": True},
        headers=_auth_header(member),
    )
    assert resp_ok.status_code == 200
    assert resp_ok.json()["status"] == "done"


# ---------------------------------------------------------------------------
# Test Cases: Rule 2 - Cannot add issues to completed or closed sprints
# ---------------------------------------------------------------------------
def test_cannot_add_issues_to_completed_sprint(client, setup_workflow_data):
    """Cannot assign issues to a COMPLETED sprint via sprint issues endpoints."""
    data = setup_workflow_data
    proj_id = data["project"].id
    member = data["member"]
    completed_sprint = data["sprint_completed"]

    resp_issue = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Backlog Item", "status": "todo"},
        headers=_auth_header(member),
    )
    issue_id = resp_issue.json()["id"]

    # 1. Batch assign endpoint: POST /sprints/{sprint_id}/issues
    resp_add = client.post(
        f"/api/v1/sprints/{completed_sprint.id}/issues",
        json={"issue_ids": [issue_id]},
        headers=_auth_header(member),
    )
    assert resp_add.status_code == 400
    assert "Cannot add issues to sprint" in resp_add.json()["detail"]
    assert "completed" in resp_add.json()["detail"]

    # 2. Single assign endpoint: POST /sprints/{sprint_id}/issues/{issue_id}
    resp_add_single = client.post(
        f"/api/v1/sprints/{completed_sprint.id}/issues/{issue_id}",
        headers=_auth_header(member),
    )
    assert resp_add_single.status_code == 400
    assert "Cannot add issues to sprint" in resp_add_single.json()["detail"]


def test_cannot_add_issues_to_closed_sprint(client, setup_workflow_data):
    """Cannot assign issues to a CLOSED sprint via sprint issues endpoints."""
    data = setup_workflow_data
    proj_id = data["project"].id
    member = data["member"]
    closed_sprint = data["sprint_closed"]

    resp_issue = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Backlog Item 2", "status": "todo"},
        headers=_auth_header(member),
    )
    issue_id = resp_issue.json()["id"]

    resp_add = client.post(
        f"/api/v1/sprints/{closed_sprint.id}/issues",
        json={"issue_ids": [issue_id]},
        headers=_auth_header(member),
    )
    assert resp_add.status_code == 400
    assert "Cannot add issues to sprint" in resp_add.json()["detail"]
    assert "closed" in resp_add.json()["detail"]


def test_cannot_create_or_update_issue_with_closed_sprint(client, setup_workflow_data):
    """Creating or updating an issue with sprint_id of a completed/closed sprint is rejected."""
    data = setup_workflow_data
    proj_id = data["project"].id
    member = data["member"]
    completed_sprint = data["sprint_completed"]
    closed_sprint = data["sprint_closed"]

    # 1. Create issue with completed sprint -> 400
    resp_create_comp = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={
            "title": "Issue in Completed Sprint",
            "sprint_id": str(completed_sprint.id),
        },
        headers=_auth_header(member),
    )
    assert resp_create_comp.status_code == 400
    assert "Cannot assign issue to sprint" in resp_create_comp.json()["detail"]

    # 2. Create normal issue
    resp_issue = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Normal Issue"},
        headers=_auth_header(member),
    )
    issue_id = resp_issue.json()["id"]

    # 3. Patch issue with closed sprint -> 400
    resp_patch = client.patch(
        f"/api/v1/issues/{issue_id}",
        json={"sprint_id": str(closed_sprint.id)},
        headers=_auth_header(member),
    )
    assert resp_patch.status_code == 400
    assert "Cannot assign issue to sprint" in resp_patch.json()["detail"]


def test_cannot_move_backlog_issue_to_closed_sprint(client, setup_workflow_data):
    """Moving an issue from backlog into a completed/closed sprint via backlog endpoint is rejected."""
    data = setup_workflow_data
    proj_id = data["project"].id
    member = data["member"]
    completed_sprint = data["sprint_completed"]

    resp_issue = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Backlog item to move"},
        headers=_auth_header(member),
    )
    issue_id = resp_issue.json()["id"]

    # Attempt to move from backlog into completed sprint
    resp_move = client.delete(
        f"/api/v1/projects/{proj_id}/backlog/issues/{issue_id}?target_sprint_id={completed_sprint.id}",
        headers=_auth_header(member),
    )
    assert resp_move.status_code == 400
    assert "Cannot assign issue to sprint" in resp_move.json()["detail"]
