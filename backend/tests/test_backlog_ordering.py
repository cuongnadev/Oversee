import pytest
from fastapi.testclient import TestClient

from app.core.security import create_access_token, hash_password
from app.db.session import get_db
from app.main import app
from app.models.enums import (
    IssuePriority,
    IssueStatus,
    RoleType,
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
def setup_ordering_data(db_session):
    ws_owner = _create_user(db_session, "ws_owner@example.com", "Workspace Owner")
    proj_admin = _create_user(db_session, "admin@example.com", "Project Admin")
    m1 = _create_user(db_session, "member1@example.com", "Member 1")
    viewer = _create_user(db_session, "viewer@example.com", "Viewer")
    outsider = _create_user(db_session, "outsider@example.com", "Outsider")

    ws = Workspace(name="Ordering Workspace", slug="ord-ws", owner_id=ws_owner.id)
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
        name="Ordering Project",
        key="ORD",
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

    sprint1 = Sprint(project_id=proj.id, name="Sprint 1")
    db_session.add(sprint1)
    db_session.commit()
    db_session.refresh(sprint1)

    # Create 4 backlog issues with ranks 10.0, 20.0, 30.0, 40.0
    i1 = Issue(
        project_id=proj.id,
        issue_number=1,
        title="Issue 1 - Alpha",
        status=IssueStatus.BACKLOG,
        priority=IssuePriority.MEDIUM,
        reporter_id=proj_admin.id,
        sprint_id=None,
        backlog_rank=10.0,
    )
    i2 = Issue(
        project_id=proj.id,
        issue_number=2,
        title="Issue 2 - Beta",
        status=IssueStatus.BACKLOG,
        priority=IssuePriority.MEDIUM,
        reporter_id=proj_admin.id,
        sprint_id=None,
        backlog_rank=20.0,
    )
    i3 = Issue(
        project_id=proj.id,
        issue_number=3,
        title="Issue 3 - Gamma",
        status=IssueStatus.BACKLOG,
        priority=IssuePriority.MEDIUM,
        reporter_id=proj_admin.id,
        sprint_id=None,
        backlog_rank=30.0,
    )
    i4 = Issue(
        project_id=proj.id,
        issue_number=4,
        title="Issue 4 - Delta",
        status=IssueStatus.BACKLOG,
        priority=IssuePriority.MEDIUM,
        reporter_id=proj_admin.id,
        sprint_id=None,
        backlog_rank=40.0,
    )

    # Issue assigned to a sprint (NOT in backlog)
    sprint_issue = Issue(
        project_id=proj.id,
        issue_number=5,
        title="Sprint Issue",
        status=IssueStatus.IN_PROGRESS,
        reporter_id=proj_admin.id,
        sprint_id=sprint1.id,
        backlog_rank=0.0,
    )

    db_session.add_all([i1, i2, i3, i4, sprint_issue])
    db_session.commit()

    return {
        "workspace": ws,
        "project": proj,
        "admin": proj_admin,
        "m1": m1,
        "viewer": viewer,
        "outsider": outsider,
        "sprint1": sprint1,
        "i1": i1,
        "i2": i2,
        "i3": i3,
        "i4": i4,
        "sprint_issue": sprint_issue,
    }


# ---------------------------------------------------------------------------
# Acceptance Criteria: Sắp xếp lại giữ nguyên sau khi reload
# ---------------------------------------------------------------------------
def test_reorder_between_issues_and_persists_on_reload(client, setup_ordering_data):
    """
    Acceptance Criteria: 'Sắp xếp lại giữ nguyên sau khi reload'.
    Moving issue 4 between issue 1 (rank 10.0) and issue 2 (rank 20.0) yields rank 15.0,
    and the new order [1, 4, 2, 3] persists on subsequent queries.
    """
    proj = setup_ordering_data["project"]
    m1 = setup_ordering_data["m1"]
    i1 = setup_ordering_data["i1"]
    i2 = setup_ordering_data["i2"]
    i4 = setup_ordering_data["i4"]

    # Reorder issue 4 between 1 and 2
    resp = client.patch(
        f"/api/v1/projects/{proj.id}/backlog/reorder",
        headers=_auth_header(m1),
        json={
            "issue_id": str(i4.id),
            "previous_issue_id": str(i1.id),
            "next_issue_id": str(i2.id),
        },
    )
    assert resp.status_code == 200
    updated_i4 = resp.json()
    assert updated_i4["backlog_rank"] == 15.0

    # Reload 1: Query backlog immediately
    resp_reload1 = client.get(
        f"/api/v1/projects/{proj.id}/backlog",
        headers=_auth_header(m1),
    )
    assert resp_reload1.status_code == 200
    order1 = [item["issue_number"] for item in resp_reload1.json()["items"]]
    assert order1 == [1, 4, 2, 3]

    # Reload 2: Separate fresh request verifies persistence
    resp_reload2 = client.get(
        f"/api/v1/projects/{proj.id}/backlog",
        headers=_auth_header(m1),
    )
    assert resp_reload2.status_code == 200
    order2 = [item["issue_number"] for item in resp_reload2.json()["items"]]
    assert order2 == [1, 4, 2, 3]


def test_reorder_to_top_via_next_issue_and_position(client, setup_ordering_data):
    """Move an issue before the first issue (to the top of the backlog)."""
    proj = setup_ordering_data["project"]
    m1 = setup_ordering_data["m1"]
    i1 = setup_ordering_data["i1"]
    i3 = setup_ordering_data["i3"]

    # Move issue 3 before issue 1 (next_issue_id=i1.id)
    resp = client.patch(
        f"/api/v1/projects/{proj.id}/backlog/reorder",
        headers=_auth_header(m1),
        json={
            "issue_id": str(i3.id),
            "next_issue_id": str(i1.id),
        },
    )
    assert resp.status_code == 200
    assert resp.json()["backlog_rank"] < 10.0

    # Reload backlog: issue 3 is now first
    resp_list = client.get(
        f"/api/v1/projects/{proj.id}/backlog",
        headers=_auth_header(m1),
    )
    assert resp_list.json()["items"][0]["issue_number"] == 3

    # Move issue 2 to the absolute top via position="top"
    i2 = setup_ordering_data["i2"]
    resp_top = client.patch(
        f"/api/v1/projects/{proj.id}/backlog/reorder",
        headers=_auth_header(m1),
        json={
            "issue_id": str(i2.id),
            "position": "top",
        },
    )
    assert resp_top.status_code == 200

    resp_list2 = client.get(
        f"/api/v1/projects/{proj.id}/backlog",
        headers=_auth_header(m1),
    )
    assert resp_list2.json()["items"][0]["issue_number"] == 2


def test_reorder_to_bottom_via_previous_issue_and_position(client, setup_ordering_data):
    """Move an issue after the last issue (to the bottom of the backlog)."""
    proj = setup_ordering_data["project"]
    m1 = setup_ordering_data["m1"]
    i1 = setup_ordering_data["i1"]
    i4 = setup_ordering_data["i4"]

    # Move issue 1 after issue 4 (previous_issue_id=i4.id)
    resp = client.patch(
        f"/api/v1/projects/{proj.id}/backlog/reorder",
        headers=_auth_header(m1),
        json={
            "issue_id": str(i1.id),
            "previous_issue_id": str(i4.id),
        },
    )
    assert resp.status_code == 200
    assert resp.json()["backlog_rank"] > 40.0

    resp_list = client.get(
        f"/api/v1/projects/{proj.id}/backlog",
        headers=_auth_header(m1),
    )
    assert resp_list.json()["items"][-1]["issue_number"] == 1

    # Move issue 2 to the absolute bottom via position="bottom"
    i2 = setup_ordering_data["i2"]
    resp_bottom = client.patch(
        f"/api/v1/projects/{proj.id}/backlog/reorder",
        headers=_auth_header(m1),
        json={
            "issue_id": str(i2.id),
            "position": "bottom",
        },
    )
    assert resp_bottom.status_code == 200

    resp_list2 = client.get(
        f"/api/v1/projects/{proj.id}/backlog",
        headers=_auth_header(m1),
    )
    assert resp_list2.json()["items"][-1]["issue_number"] == 2


def test_reorder_via_dedicated_issue_rank_endpoint(client, setup_ordering_data):
    """PATCH /api/v1/issues/{id}/rank updates backlog rank and logs activity."""
    m1 = setup_ordering_data["m1"]
    i1 = setup_ordering_data["i1"]
    i2 = setup_ordering_data["i2"]
    i3 = setup_ordering_data["i3"]

    # Move i1 between i2 and i3
    resp = client.patch(
        f"/api/v1/issues/{i1.id}/rank",
        headers=_auth_header(m1),
        json={
            "previous_issue_id": str(i2.id),
            "next_issue_id": str(i3.id),
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["backlog_rank"] == 25.0

    # Activity log recorded
    resp_act = client.get(
        f"/api/v1/issues/{i1.id}/activities",
        headers=_auth_header(m1),
    )
    assert resp_act.status_code == 200
    actions = [a["action"] for a in resp_act.json()]
    assert "backlog_reordered" in actions


def test_reorder_explicit_target_rank(client, setup_ordering_data):
    """Set target_rank explicitly."""
    proj = setup_ordering_data["project"]
    m1 = setup_ordering_data["m1"]
    i1 = setup_ordering_data["i1"]

    resp = client.patch(
        f"/api/v1/projects/{proj.id}/backlog/reorder",
        headers=_auth_header(m1),
        json={
            "issue_id": str(i1.id),
            "target_rank": 99.5,
        },
    )
    assert resp.status_code == 200
    assert resp.json()["backlog_rank"] == 99.5


def test_reorder_rebalance_trigger_on_tight_gap(
    client, setup_ordering_data, db_session
):
    """
    When ranks are too close (< 1e-6), the system automatically rebalances
    the backlog ranks to spaced intervals before calculating the new midpoint.
    """
    proj = setup_ordering_data["project"]
    m1 = setup_ordering_data["m1"]
    i1 = setup_ordering_data["i1"]
    i2 = setup_ordering_data["i2"]
    i3 = setup_ordering_data["i3"]

    # Artificially set very tight ranks: i1 = 10.0, i2 = 10.00000001
    i1.backlog_rank = 10.0
    i2.backlog_rank = 10.0000001
    db_session.commit()

    # Move i3 between i1 and i2 (triggering rebalance)
    resp = client.patch(
        f"/api/v1/projects/{proj.id}/backlog/reorder",
        headers=_auth_header(m1),
        json={
            "issue_id": str(i3.id),
            "previous_issue_id": str(i1.id),
            "next_issue_id": str(i2.id),
        },
    )
    assert resp.status_code == 200
    # After rebalance, i1=10, i2=20, so i3 placed between them gets rank 15.0
    assert resp.json()["backlog_rank"] == 15.0


def test_reorder_validation_errors(client, setup_ordering_data):
    """Validation errors: self-positioning, non-backlog issues, nonexistent IDs."""
    proj = setup_ordering_data["project"]
    m1 = setup_ordering_data["m1"]
    i1 = setup_ordering_data["i1"]
    sprint_issue = setup_ordering_data["sprint_issue"]

    # Cannot position relative to itself
    resp_self = client.patch(
        f"/api/v1/projects/{proj.id}/backlog/reorder",
        headers=_auth_header(m1),
        json={
            "issue_id": str(i1.id),
            "previous_issue_id": str(i1.id),
        },
    )
    assert resp_self.status_code == 400
    assert "Cannot position an issue relative to itself" in resp_self.json()["detail"]

    # Cannot reorder an issue currently in a sprint
    resp_sprint = client.patch(
        f"/api/v1/projects/{proj.id}/backlog/reorder",
        headers=_auth_header(m1),
        json={
            "issue_id": str(sprint_issue.id),
            "position": "top",
        },
    )
    assert resp_sprint.status_code == 400
    assert "Only issues in the product backlog" in resp_sprint.json()["detail"]

    # Nonexistent previous issue
    resp_bad_prev = client.patch(
        f"/api/v1/projects/{proj.id}/backlog/reorder",
        headers=_auth_header(m1),
        json={
            "issue_id": str(i1.id),
            "previous_issue_id": "00000000-0000-0000-0000-000000000000",
        },
    )
    assert resp_bad_prev.status_code == 404


def test_reorder_permissions(client, setup_ordering_data):
    """Permissions: Member can reorder; Viewer cannot (403); Outsider 404; Unauth 401."""
    proj = setup_ordering_data["project"]
    viewer = setup_ordering_data["viewer"]
    outsider = setup_ordering_data["outsider"]
    i1 = setup_ordering_data["i1"]

    # Viewer 403
    resp_v = client.patch(
        f"/api/v1/projects/{proj.id}/backlog/reorder",
        headers=_auth_header(viewer),
        json={"issue_id": str(i1.id), "position": "top"},
    )
    assert resp_v.status_code == 403

    # Outsider 404
    resp_o = client.patch(
        f"/api/v1/projects/{proj.id}/backlog/reorder",
        headers=_auth_header(outsider),
        json={"issue_id": str(i1.id), "position": "top"},
    )
    assert resp_o.status_code == 404

    # Unauthenticated 401
    resp_u = client.patch(
        f"/api/v1/projects/{proj.id}/backlog/reorder",
        json={"issue_id": str(i1.id), "position": "top"},
    )
    assert resp_u.status_code == 401
