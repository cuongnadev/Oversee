import uuid
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from app.core.security import create_access_token, hash_password
from app.db.session import get_db
from app.main import app
from app.models.enums import (
    IssueStatus,
    RoleType,
    SprintStatus,
)
from app.models.issue import Issue
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
def setup_lifecycle_data(db_session):
    ws_owner = _create_user(db_session, "ws_owner@example.com", "Workspace Owner")
    proj_admin = _create_user(db_session, "admin@example.com", "Project Admin")
    m1 = _create_user(db_session, "member1@example.com", "Member 1")
    viewer = _create_user(db_session, "viewer@example.com", "Viewer")
    outsider = _create_user(db_session, "outsider@example.com", "Outsider")

    ws = Workspace(
        name="Lifecycle Workspace", slug="lifecycle-ws", owner_id=ws_owner.id
    )
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
        name="Lifecycle Project",
        key="LCY",
    )
    proj2 = Project(
        workspace_id=ws.id,
        name="Lifecycle Project 2",
        key="LC2",
    )
    db_session.add_all([proj, proj2])
    db_session.commit()
    db_session.refresh(proj)
    db_session.refresh(proj2)

    for u, r in [
        (proj_admin, RoleType.ADMIN),
        (m1, RoleType.MEMBER),
        (viewer, RoleType.VIEWER),
    ]:
        db_session.add(ProjectMember(project_id=proj.id, user_id=u.id, role=r))
    db_session.add(
        ProjectMember(project_id=proj2.id, user_id=m1.id, role=RoleType.MEMBER)
    )
    db_session.commit()

    # Sprints in Project 1
    sprint1 = Sprint(
        project_id=proj.id,
        name="Sprint Alpha",
        status=SprintStatus.PLANNED,
    )
    sprint2 = Sprint(
        project_id=proj.id,
        name="Sprint Beta",
        status=SprintStatus.PLANNED,
    )
    # Sprint in Project 2
    sprint_other = Sprint(
        project_id=proj2.id,
        name="Sprint Other",
        status=SprintStatus.PLANNED,
    )
    db_session.add_all([sprint1, sprint2, sprint_other])
    db_session.commit()
    db_session.refresh(sprint1)
    db_session.refresh(sprint2)
    db_session.refresh(sprint_other)

    return {
        "admin": proj_admin,
        "member": m1,
        "viewer": viewer,
        "outsider": outsider,
        "project": proj,
        "project2": proj2,
        "sprint1": sprint1,
        "sprint2": sprint2,
        "sprint_other": sprint_other,
    }


# ---------------------------------------------------------------------------
# Test Cases
# ---------------------------------------------------------------------------
def test_start_sprint_success(client, setup_lifecycle_data, db_session):
    """Member can start a planned sprint. Status becomes ACTIVE."""
    data = setup_lifecycle_data
    sprint1_id = data["sprint1"].id

    resp = client.post(
        f"/api/v1/sprints/{sprint1_id}/start",
        headers=_auth_header(data["member"]),
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "active"
    assert body["start_date"] is not None

    db_session.refresh(data["sprint1"])
    assert data["sprint1"].status == SprintStatus.ACTIVE


def test_start_sprint_with_custom_dates(client, setup_lifecycle_data):
    """Can specify start_date and end_date upon starting."""
    data = setup_lifecycle_data
    sprint1_id = data["sprint1"].id

    start = datetime.now(UTC)
    end = start + timedelta(days=14)

    resp = client.post(
        f"/api/v1/sprints/{sprint1_id}/start",
        json={"start_date": start.isoformat(), "end_date": end.isoformat()},
        headers=_auth_header(data["member"]),
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "active"


def test_start_sprint_invalid_dates_fails(client, setup_lifecycle_data):
    """Validation error if start_date >= end_date when starting."""
    data = setup_lifecycle_data
    sprint1_id = data["sprint1"].id

    now = datetime.now(UTC)
    resp = client.post(
        f"/api/v1/sprints/{sprint1_id}/start",
        json={
            "start_date": (now + timedelta(days=10)).isoformat(),
            "end_date": now.isoformat(),
        },
        headers=_auth_header(data["member"]),
    )
    assert resp.status_code == 422


def test_start_sprint_only_one_active_enforced(client, setup_lifecycle_data):
    """Cannot start a second sprint when an active sprint already exists in the project."""
    data = setup_lifecycle_data
    sprint1_id = data["sprint1"].id
    sprint2_id = data["sprint2"].id

    # 1. Start Sprint 1 -> succeeds
    r1 = client.post(
        f"/api/v1/sprints/{sprint1_id}/start",
        headers=_auth_header(data["member"]),
    )
    assert r1.status_code == 200

    # 2. Try to start Sprint 2 while Sprint 1 is active -> 400 Bad Request
    r2 = client.post(
        f"/api/v1/sprints/{sprint2_id}/start",
        headers=_auth_header(data["member"]),
    )
    assert r2.status_code == 400
    assert "Only one active sprint" in r2.json()["detail"]


def test_start_non_planned_sprint_fails(client, setup_lifecycle_data):
    """Cannot start an already active or completed sprint."""
    data = setup_lifecycle_data
    sprint1_id = data["sprint1"].id

    # Start it once
    client.post(
        f"/api/v1/sprints/{sprint1_id}/start", headers=_auth_header(data["member"])
    )

    # Attempt to start again
    resp2 = client.post(
        f"/api/v1/sprints/{sprint1_id}/start",
        headers=_auth_header(data["member"]),
    )
    assert resp2.status_code == 400
    assert "Cannot start sprint in 'active' status" in resp2.json()["detail"]


def test_complete_sprint_move_incomplete_to_backlog(
    client, setup_lifecycle_data, db_session
):
    """
    Acceptance Criteria: Hoàn thành sprint xử lý đúng issue dang dở.
    - Completed issues (DONE) remain in completed sprint.
    - Incomplete issues (TODO, IN_PROGRESS) are returned to backlog when no target sprint is specified.
    """
    data = setup_lifecycle_data
    proj_id = data["project"].id
    sprint1_id = data["sprint1"].id

    # Start sprint
    client.post(
        f"/api/v1/sprints/{sprint1_id}/start", headers=_auth_header(data["member"])
    )

    # Seed 3 issues in sprint: 1 DONE, 1 IN_PROGRESS, 1 TODO
    done_issue = Issue(
        project_id=proj_id,
        issue_number=1,
        title="Completed Task",
        status=IssueStatus.DONE,
        reporter_id=data["admin"].id,
        sprint_id=sprint1_id,
    )
    in_prog_issue = Issue(
        project_id=proj_id,
        issue_number=2,
        title="In-progress Task",
        status=IssueStatus.IN_PROGRESS,
        reporter_id=data["admin"].id,
        sprint_id=sprint1_id,
    )
    todo_issue = Issue(
        project_id=proj_id,
        issue_number=3,
        title="Todo Task",
        status=IssueStatus.TODO,
        reporter_id=data["admin"].id,
        sprint_id=sprint1_id,
    )
    db_session.add_all([done_issue, in_prog_issue, todo_issue])
    db_session.commit()

    # Complete sprint without target sprint (move incomplete to backlog)
    resp = client.post(
        f"/api/v1/sprints/{sprint1_id}/complete",
        headers=_auth_header(data["member"]),
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["sprint"]["status"] == "completed"
    assert body["completed_issues_count"] == 1
    assert body["incomplete_issues_count"] == 2
    assert body["moved_to_backlog"] is True
    assert body["moved_to_sprint_id"] is None

    # Check database state:
    db_session.refresh(done_issue)
    db_session.refresh(in_prog_issue)
    db_session.refresh(todo_issue)

    # Done issue remains in sprint1
    assert done_issue.sprint_id == sprint1_id
    assert done_issue.is_backlog is False

    # Incomplete issues moved to backlog (sprint_id = None)
    assert in_prog_issue.sprint_id is None
    assert in_prog_issue.is_backlog is True

    assert todo_issue.sprint_id is None
    assert todo_issue.is_backlog is True


def test_complete_sprint_move_incomplete_to_next_sprint(
    client, setup_lifecycle_data, db_session
):
    """
    Acceptance Criteria: Incomplete issues move to target next sprint when target_sprint_id is provided.
    """
    data = setup_lifecycle_data
    proj_id = data["project"].id
    sprint1_id = data["sprint1"].id
    sprint2_id = data["sprint2"].id

    # Start sprint 1
    client.post(
        f"/api/v1/sprints/{sprint1_id}/start", headers=_auth_header(data["member"])
    )

    done_issue = Issue(
        project_id=proj_id,
        issue_number=10,
        title="Finished Story",
        status=IssueStatus.DONE,
        reporter_id=data["admin"].id,
        sprint_id=sprint1_id,
    )
    unfinished_issue = Issue(
        project_id=proj_id,
        issue_number=11,
        title="Unfinished Bug",
        status=IssueStatus.IN_REVIEW,
        reporter_id=data["admin"].id,
        sprint_id=sprint1_id,
    )
    db_session.add_all([done_issue, unfinished_issue])
    db_session.commit()

    # Complete sprint 1 and specify target_sprint_id = sprint2_id
    resp = client.post(
        f"/api/v1/sprints/{sprint1_id}/complete",
        json={"target_sprint_id": str(sprint2_id)},
        headers=_auth_header(data["member"]),
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["completed_issues_count"] == 1
    assert body["incomplete_issues_count"] == 1
    assert body["moved_to_sprint_id"] == str(sprint2_id)

    db_session.refresh(done_issue)
    db_session.refresh(unfinished_issue)

    # Done issue stayed in sprint 1
    assert done_issue.sprint_id == sprint1_id
    # Unfinished issue moved to sprint 2
    assert unfinished_issue.sprint_id == sprint2_id


def test_complete_sprint_invalid_transitions(client, setup_lifecycle_data):
    """Cannot complete a planned sprint or specify invalid target sprints."""
    data = setup_lifecycle_data
    sprint1_id = data["sprint1"].id
    other_sprint_id = data["sprint_other"].id

    # Cannot complete a PLANNED sprint
    resp1 = client.post(
        f"/api/v1/sprints/{sprint1_id}/complete",
        headers=_auth_header(data["member"]),
    )
    assert resp1.status_code == 400
    assert "Cannot complete sprint in 'planned' status" in resp1.json()["detail"]

    # Start sprint 1
    client.post(
        f"/api/v1/sprints/{sprint1_id}/start", headers=_auth_header(data["member"])
    )

    # Cannot specify target sprint belonging to another project
    resp2 = client.post(
        f"/api/v1/sprints/{sprint1_id}/complete",
        json={"target_sprint_id": str(other_sprint_id)},
        headers=_auth_header(data["member"]),
    )
    assert resp2.status_code == 400
    assert "Target sprint must belong to the same project" in resp2.json()["detail"]

    # Cannot specify target sprint as the same sprint being completed
    resp3 = client.post(
        f"/api/v1/sprints/{sprint1_id}/complete",
        json={"target_sprint_id": str(sprint1_id)},
        headers=_auth_header(data["member"]),
    )
    assert resp3.status_code == 400
    assert "Cannot move incomplete issues to the same sprint" in resp3.json()["detail"]

    # Cannot specify non-existent target sprint -> 404
    resp4 = client.post(
        f"/api/v1/sprints/{sprint1_id}/complete",
        json={"target_sprint_id": str(uuid.uuid4())},
        headers=_auth_header(data["member"]),
    )
    assert resp4.status_code == 404


def test_sprint_lifecycle_permissions(client, setup_lifecycle_data):
    """Test RBAC for start/complete: VIEWER cannot, MEMBER can, OUTSIDER 404, unauth 401."""
    data = setup_lifecycle_data
    sprint1_id = data["sprint1"].id

    # 1. VIEWER cannot start sprint -> 403
    r_viewer = client.post(
        f"/api/v1/sprints/{sprint1_id}/start",
        headers=_auth_header(data["viewer"]),
    )
    assert r_viewer.status_code == 403

    # 2. OUTSIDER gets 404
    r_outsider = client.post(
        f"/api/v1/sprints/{sprint1_id}/start",
        headers=_auth_header(data["outsider"]),
    )
    assert r_outsider.status_code == 404

    # 3. Unauthenticated gets 401
    r_unauth = client.post(f"/api/v1/sprints/{sprint1_id}/start")
    assert r_unauth.status_code == 401

    # 4. MEMBER starts -> 200
    r_start = client.post(
        f"/api/v1/sprints/{sprint1_id}/start",
        headers=_auth_header(data["member"]),
    )
    assert r_start.status_code == 200

    # 5. VIEWER cannot complete sprint -> 403
    r_viewer_comp = client.post(
        f"/api/v1/sprints/{sprint1_id}/complete",
        headers=_auth_header(data["viewer"]),
    )
    assert r_viewer_comp.status_code == 403

    # 6. MEMBER completes -> 200
    r_complete = client.post(
        f"/api/v1/sprints/{sprint1_id}/complete",
        headers=_auth_header(data["member"]),
    )
    assert r_complete.status_code == 200
