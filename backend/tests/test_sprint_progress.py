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
def setup_progress_data(db_session):
    ws_owner = _create_user(db_session, "ws_owner@example.com", "Workspace Owner")
    proj_admin = _create_user(db_session, "admin@example.com", "Project Admin")
    m1 = _create_user(db_session, "member1@example.com", "Member 1")
    viewer = _create_user(db_session, "viewer@example.com", "Viewer")
    outsider = _create_user(db_session, "outsider@example.com", "Outsider")

    ws = Workspace(name="Progress Workspace", slug="progress-ws", owner_id=ws_owner.id)
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
        name="Progress Project",
        key="PRG",
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

    now = datetime.now(UTC)
    start_d = now - timedelta(days=2)
    end_d = now + timedelta(days=5)

    sprint = Sprint(
        project_id=proj.id,
        name="Sprint Progress 1",
        status=SprintStatus.ACTIVE,
        start_date=start_d,
        end_date=end_d,
        capacity=25.0,
    )
    empty_sprint = Sprint(
        project_id=proj.id,
        name="Empty Sprint",
        status=SprintStatus.PLANNED,
    )
    db_session.add_all([sprint, empty_sprint])
    db_session.commit()
    db_session.refresh(sprint)
    db_session.refresh(empty_sprint)

    # 4 issues in sprint:
    # Issue 1: DONE, estimate = 3.0
    i1 = Issue(
        project_id=proj.id,
        issue_number=1,
        title="Completed Task 1",
        status=IssueStatus.DONE,
        type=IssueType.TASK,
        priority=IssuePriority.HIGH,
        reporter_id=proj_admin.id,
        sprint_id=sprint.id,
        estimate=3.0,
    )
    # Issue 2: DONE, estimate = 5.0
    i2 = Issue(
        project_id=proj.id,
        issue_number=2,
        title="Completed Task 2",
        status=IssueStatus.DONE,
        type=IssueType.STORY,
        priority=IssuePriority.MEDIUM,
        reporter_id=proj_admin.id,
        sprint_id=sprint.id,
        estimate=5.0,
    )
    # Issue 3: IN_PROGRESS, estimate = 8.0
    i3 = Issue(
        project_id=proj.id,
        issue_number=3,
        title="In-progress Task",
        status=IssueStatus.IN_PROGRESS,
        type=IssueType.TASK,
        priority=IssuePriority.MEDIUM,
        reporter_id=proj_admin.id,
        sprint_id=sprint.id,
        estimate=8.0,
    )
    # Issue 4: TODO, estimate = 4.0
    i4 = Issue(
        project_id=proj.id,
        issue_number=4,
        title="Todo Task",
        status=IssueStatus.TODO,
        type=IssueType.BUG,
        priority=IssuePriority.LOW,
        reporter_id=proj_admin.id,
        sprint_id=sprint.id,
        estimate=4.0,
    )
    # Issue 5: TODO, estimate = None (should be handled gracefully as 0.0)
    i5 = Issue(
        project_id=proj.id,
        issue_number=5,
        title="Unestimated Task",
        status=IssueStatus.TODO,
        type=IssueType.TASK,
        priority=IssuePriority.LOW,
        reporter_id=proj_admin.id,
        sprint_id=sprint.id,
        estimate=None,
    )
    db_session.add_all([i1, i2, i3, i4, i5])
    db_session.commit()

    return {
        "admin": proj_admin,
        "member": m1,
        "viewer": viewer,
        "outsider": outsider,
        "project": proj,
        "sprint": sprint,
        "empty_sprint": empty_sprint,
    }


# ---------------------------------------------------------------------------
# Test Cases
# ---------------------------------------------------------------------------
def test_sprint_progress_calculation(client, setup_progress_data):
    """
    Acceptance Criteria:
    - Tính % theo số issue: 2 DONE / 5 total = 40.0%
    - Tính % theo story points: (3.0 + 5.0) / (3.0 + 5.0 + 8.0 + 4.0 + 0.0) = 8.0 / 20.0 = 40.0%
    - Remaining story points = 12.0
    - Status breakdown matches actual distribution
    """
    data = setup_progress_data
    sprint_id = data["sprint"].id

    resp = client.get(
        f"/api/v1/sprints/{sprint_id}/progress",
        headers=_auth_header(data["viewer"]),
    )
    assert resp.status_code == 200
    body = resp.json()

    # Issue count progress
    assert body["sprint_id"] == str(sprint_id)
    assert body["sprint_name"] == "Sprint Progress 1"
    assert body["status"] == "active"
    assert body["total_issues"] == 5
    assert body["completed_issues"] == 2
    assert body["remaining_issues"] == 3
    assert body["issue_progress_percentage"] == 40.0

    # Story points progress
    assert body["total_story_points"] == 20.0
    assert body["completed_story_points"] == 8.0
    assert body["remaining_story_points"] == 12.0
    assert body["story_point_progress_percentage"] == 40.0

    # Status breakdown
    breakdown = body["status_breakdown"]
    assert breakdown["done"] == 2
    assert breakdown["in_progress"] == 1
    assert breakdown["todo"] == 2


def test_empty_sprint_progress(client, setup_progress_data):
    """Sprint without issues returns 0.0% without zero-division error."""
    data = setup_progress_data
    empty_sprint_id = data["empty_sprint"].id

    resp = client.get(
        f"/api/v1/sprints/{empty_sprint_id}/progress",
        headers=_auth_header(data["viewer"]),
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["total_issues"] == 0
    assert body["completed_issues"] == 0
    assert body["remaining_issues"] == 0
    assert body["issue_progress_percentage"] == 0.0
    assert body["total_story_points"] == 0.0
    assert body["completed_story_points"] == 0.0
    assert body["remaining_story_points"] == 0.0
    assert body["story_point_progress_percentage"] == 0.0
    assert body["status_breakdown"] == {}
    assert body["burndown"] == []


def test_sprint_burndown_data(client, setup_progress_data):
    """
    Acceptance Criteria: Dữ liệu burndown cơ bản.
    - Burndown points exist for each day from start_date to end_date.
    - Day 0 ideal_remaining equals total_story_points (20.0).
    - Last day ideal_remaining equals 0.0.
    """
    data = setup_progress_data
    sprint_id = data["sprint"].id

    resp = client.get(
        f"/api/v1/sprints/{sprint_id}/progress",
        headers=_auth_header(data["member"]),
    )
    assert resp.status_code == 200
    burndown = resp.json()["burndown"]
    assert len(burndown) == 8  # 7 days span -> 8 boundary points (days 0 to 7)

    # First point: ideal = 20.0
    assert burndown[0]["ideal_remaining"] == 20.0
    # Final point: ideal = 0.0
    assert burndown[-1]["ideal_remaining"] == 0.0

    # Ideal descends monotonically
    ideal_values = [p["ideal_remaining"] for p in burndown]
    assert ideal_values == sorted(ideal_values, reverse=True)


def test_sprint_progress_permissions(client, setup_progress_data):
    """RBAC: VIEWER and MEMBER can access; OUTSIDER gets 404; unauthenticated gets 401."""
    data = setup_progress_data
    sprint_id = data["sprint"].id

    # 1. VIEWER can access -> 200
    r_viewer = client.get(
        f"/api/v1/sprints/{sprint_id}/progress",
        headers=_auth_header(data["viewer"]),
    )
    assert r_viewer.status_code == 200

    # 2. MEMBER can access -> 200
    r_member = client.get(
        f"/api/v1/sprints/{sprint_id}/progress",
        headers=_auth_header(data["member"]),
    )
    assert r_member.status_code == 200

    # 3. OUTSIDER gets 404
    r_outsider = client.get(
        f"/api/v1/sprints/{sprint_id}/progress",
        headers=_auth_header(data["outsider"]),
    )
    assert r_outsider.status_code == 404

    # 4. Unauthenticated gets 401
    r_unauth = client.get(f"/api/v1/sprints/{sprint_id}/progress")
    assert r_unauth.status_code == 401
