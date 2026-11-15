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
def setup_backlog_data(db_session):
    ws_owner = _create_user(db_session, "ws_owner@example.com", "Workspace Owner")
    proj_admin = _create_user(db_session, "admin@example.com", "Project Admin")
    m1 = _create_user(db_session, "member1@example.com", "Member 1")
    viewer = _create_user(db_session, "viewer@example.com", "Viewer")
    outsider = _create_user(db_session, "outsider@example.com", "Outsider")

    ws = Workspace(name="Backlog Workspace", slug="backlog-ws", owner_id=ws_owner.id)
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
        name="Backlog Project",
        key="BKL",
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

    # Seed 3 issues in Backlog (sprint_id is None)
    b1 = Issue(
        project_id=proj.id,
        issue_number=1,
        title="Backlog Item 1",
        description="First backlog item",
        type=IssueType.TASK,
        status=IssueStatus.BACKLOG,
        priority=IssuePriority.MEDIUM,
        reporter_id=proj_admin.id,
        assignee_id=m1.id,
        sprint_id=None,
        backlog_rank=10.0,
    )
    b2 = Issue(
        project_id=proj.id,
        issue_number=2,
        title="Backlog Item 2 - Urgent Bug",
        description="Critical bug in backlog",
        type=IssueType.BUG,
        status=IssueStatus.TODO,
        priority=IssuePriority.URGENT,
        reporter_id=proj_admin.id,
        assignee_id=None,
        sprint_id=None,
        backlog_rank=20.0,
    )
    b3 = Issue(
        project_id=proj.id,
        issue_number=3,
        title="Backlog Item 3",
        description="Low priority story",
        type=IssueType.STORY,
        status=IssueStatus.BACKLOG,
        priority=IssuePriority.LOW,
        reporter_id=proj_admin.id,
        assignee_id=m1.id,
        sprint_id=None,
        backlog_rank=30.0,
    )

    # Seed 2 issues assigned to Sprint 1 (NOT in backlog)
    s1 = Issue(
        project_id=proj.id,
        issue_number=4,
        title="Sprint 1 Task A",
        type=IssueType.TASK,
        status=IssueStatus.IN_PROGRESS,
        priority=IssuePriority.HIGH,
        reporter_id=proj_admin.id,
        assignee_id=m1.id,
        sprint_id=sprint1.id,
        backlog_rank=0.0,
    )
    s2 = Issue(
        project_id=proj.id,
        issue_number=5,
        title="Sprint 1 Task B",
        type=IssueType.TASK,
        status=IssueStatus.DONE,
        priority=IssuePriority.HIGH,
        reporter_id=proj_admin.id,
        assignee_id=m1.id,
        sprint_id=sprint1.id,
        backlog_rank=0.0,
    )

    db_session.add_all([b1, b2, b3, s1, s2])
    db_session.commit()

    return {
        "workspace": ws,
        "project": proj,
        "admin": proj_admin,
        "m1": m1,
        "viewer": viewer,
        "outsider": outsider,
        "sprint1": sprint1,
        "b1": b1,
        "b2": b2,
        "b3": b3,
        "s1": s1,
        "s2": s2,
    }


# ---------------------------------------------------------------------------
# Acceptance Criteria: Backlog chỉ chứa issue chưa gắn sprint
# ---------------------------------------------------------------------------
def test_list_backlog_only_contains_issues_without_sprint(client, setup_backlog_data):
    """
    Acceptance Criteria: 'Backlog chỉ chứa issue chưa gắn sprint'.
    Returns only issues where sprint_id is None and is_backlog is True.
    """
    proj = setup_backlog_data["project"]
    viewer = setup_backlog_data["viewer"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/backlog",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 200
    data = resp.json()

    # Exactly 3 backlog issues returned out of 5 total project issues
    assert data["total"] == 3
    assert len(data["items"]) == 3

    for item in data["items"]:
        assert item["sprint_id"] is None
        assert item["is_backlog"] is True
        assert item["issue_number"] in [1, 2, 3]

    # Sprint issues 4 and 5 must NOT appear in backlog
    issue_numbers = {i["issue_number"] for i in data["items"]}
    assert 4 not in issue_numbers
    assert 5 not in issue_numbers


# ---------------------------------------------------------------------------
# Backlog Filtering & Sorting Tests
# ---------------------------------------------------------------------------
def test_backlog_filtering(client, setup_backlog_data):
    """Filter backlog issues by status, priority, type, and keyword search."""
    proj = setup_backlog_data["project"]
    viewer = setup_backlog_data["viewer"]

    # Filter by priority=urgent (only issue 2)
    resp_prio = client.get(
        f"/api/v1/projects/{proj.id}/backlog?priority=urgent",
        headers=_auth_header(viewer),
    )
    assert resp_prio.status_code == 200
    data_prio = resp_prio.json()
    assert data_prio["total"] == 1
    assert data_prio["items"][0]["issue_number"] == 2

    # Filter by status=backlog (issues 1 and 3)
    resp_status = client.get(
        f"/api/v1/projects/{proj.id}/backlog?status=backlog",
        headers=_auth_header(viewer),
    )
    assert resp_status.status_code == 200
    data_status = resp_status.json()
    assert data_status["total"] == 2
    assert {i["issue_number"] for i in data_status["items"]} == {1, 3}

    # Filter by search keyword
    resp_search = client.get(
        f"/api/v1/projects/{proj.id}/backlog?search=Critical",
        headers=_auth_header(viewer),
    )
    assert resp_search.status_code == 200
    assert resp_search.json()["total"] == 1
    assert resp_search.json()["items"][0]["issue_number"] == 2


def test_backlog_default_order_and_custom_sorting(client, setup_backlog_data):
    """Backlog defaults to backlog_rank:asc, and respects custom sorting."""
    proj = setup_backlog_data["project"]
    viewer = setup_backlog_data["viewer"]

    # Default order: backlog_rank ascending (10.0, 20.0, 30.0 -> issues 1, 2, 3)
    resp_default = client.get(
        f"/api/v1/projects/{proj.id}/backlog",
        headers=_auth_header(viewer),
    )
    assert resp_default.status_code == 200
    numbers = [i["issue_number"] for i in resp_default.json()["items"]]
    assert numbers == [1, 2, 3]

    # Custom order: priority descending (urgent -> medium -> low -> issues 2, 1, 3)
    resp_sort = client.get(
        f"/api/v1/projects/{proj.id}/backlog?sort=priority:desc",
        headers=_auth_header(viewer),
    )
    assert resp_sort.status_code == 200
    numbers_sorted = [i["issue_number"] for i in resp_sort.json()["items"]]
    assert numbers_sorted == [2, 1, 3]


def test_backlog_pagination_offset_and_cursor(client, setup_backlog_data):
    """Backlog pagination supports both offset (page, page_size) and cursor."""
    proj = setup_backlog_data["project"]
    viewer = setup_backlog_data["viewer"]

    # Offset: Page 1, size 2
    resp_p1 = client.get(
        f"/api/v1/projects/{proj.id}/backlog?page=1&page_size=2",
        headers=_auth_header(viewer),
    )
    assert resp_p1.status_code == 200
    d1 = resp_p1.json()
    assert d1["total"] == 3
    assert d1["total_pages"] == 2
    assert len(d1["items"]) == 2
    assert d1["has_more"] is True
    assert d1["next_cursor"] is not None

    # Cursor: Page 2 using next_cursor
    cursor = d1["next_cursor"]
    resp_p2 = client.get(
        f"/api/v1/projects/{proj.id}/backlog?page_size=2&cursor={cursor}",
        headers=_auth_header(viewer),
    )
    assert resp_p2.status_code == 200
    d2 = resp_p2.json()
    assert len(d2["items"]) == 1
    assert d2["items"][0]["issue_number"] == 3
    assert d2["has_more"] is False
    assert d2["next_cursor"] is None


# ---------------------------------------------------------------------------
# Add / Move Issues to Backlog Tests
# ---------------------------------------------------------------------------
def test_add_sprint_issues_to_backlog_bulk(client, setup_backlog_data):
    """Move issues from sprint into the backlog in bulk."""
    proj = setup_backlog_data["project"]
    m1 = setup_backlog_data["m1"]
    s1 = setup_backlog_data["s1"]
    s2 = setup_backlog_data["s2"]

    # Initially s1 and s2 are in sprint1
    resp_add = client.post(
        f"/api/v1/projects/{proj.id}/backlog/issues",
        headers=_auth_header(m1),
        json={"issue_ids": [str(s1.id), str(s2.id)]},
    )
    assert resp_add.status_code == 200
    results = resp_add.json()
    assert len(results) == 2
    for item in results:
        assert item["sprint_id"] is None
        assert item["is_backlog"] is True

    # Check backlog now contains 5 issues
    resp_backlog = client.get(
        f"/api/v1/projects/{proj.id}/backlog",
        headers=_auth_header(m1),
    )
    assert resp_backlog.json()["total"] == 5


def test_add_single_issue_to_backlog(client, setup_backlog_data):
    """Add a single issue to backlog using issue_id field or dedicated endpoint."""
    proj = setup_backlog_data["project"]
    m1 = setup_backlog_data["m1"]
    s1 = setup_backlog_data["s1"]
    s2 = setup_backlog_data["s2"]

    # Using single issue_id field in project endpoint
    resp_proj = client.post(
        f"/api/v1/projects/{proj.id}/backlog/issues",
        headers=_auth_header(m1),
        json={"issue_id": str(s2.id)},
    )
    assert resp_proj.status_code == 200
    assert resp_proj.json()[0]["sprint_id"] is None

    # Dedicated endpoint: POST /api/v1/issues/{id}/backlog
    resp = client.post(
        f"/api/v1/issues/{s1.id}/backlog",
        headers=_auth_header(m1),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["sprint_id"] is None
    assert data["is_backlog"] is True

    # Activity log recorded
    resp_act = client.get(
        f"/api/v1/issues/{s1.id}/activities",
        headers=_auth_header(m1),
    )
    assert resp_act.status_code == 200
    actions = [a["action"] for a in resp_act.json()]
    assert "moved_to_backlog" in actions


# ---------------------------------------------------------------------------
# Remove Issues from Backlog Tests
# ---------------------------------------------------------------------------
def test_remove_issue_from_backlog_delete(client, setup_backlog_data):
    """Delete an issue from the product backlog (requires ADMIN)."""
    proj = setup_backlog_data["project"]
    admin = setup_backlog_data["admin"]
    b1 = setup_backlog_data["b1"]

    resp_del = client.delete(
        f"/api/v1/projects/{proj.id}/backlog/issues/{b1.id}",
        headers=_auth_header(admin),
    )
    assert resp_del.status_code == 204

    # Backlog now has 2 issues remaining
    resp_backlog = client.get(
        f"/api/v1/projects/{proj.id}/backlog",
        headers=_auth_header(admin),
    )
    assert resp_backlog.json()["total"] == 2
    numbers = {i["issue_number"] for i in resp_backlog.json()["items"]}
    assert 1 not in numbers


def test_remove_issue_from_backlog_move_to_sprint(client, setup_backlog_data):
    """Remove issue from backlog by assigning it to a sprint."""
    proj = setup_backlog_data["project"]
    m1 = setup_backlog_data["m1"]
    b2 = setup_backlog_data["b2"]
    sprint1 = setup_backlog_data["sprint1"]

    resp_move = client.delete(
        f"/api/v1/projects/{proj.id}/backlog/issues/{b2.id}?target_sprint_id={sprint1.id}",
        headers=_auth_header(m1),
    )
    assert resp_move.status_code == 204

    # Issue 2 now has sprint_id and is no longer in backlog
    resp_issue = client.get(
        f"/api/v1/issues/{b2.id}",
        headers=_auth_header(m1),
    )
    assert resp_issue.status_code == 200
    assert resp_issue.json()["sprint_id"] == str(sprint1.id)
    assert resp_issue.json()["is_backlog"] is False

    # Backlog total reduced to 2
    resp_backlog = client.get(
        f"/api/v1/projects/{proj.id}/backlog",
        headers=_auth_header(m1),
    )
    assert resp_backlog.json()["total"] == 2


# ---------------------------------------------------------------------------
# Permissions & Validation Tests
# ---------------------------------------------------------------------------
def test_backlog_permissions(client, setup_backlog_data):
    """Permissions: Viewer can list; Member can add; Member cannot delete; Outsider 404."""
    proj = setup_backlog_data["project"]
    viewer = setup_backlog_data["viewer"]
    m1 = setup_backlog_data["m1"]
    outsider = setup_backlog_data["outsider"]
    b1 = setup_backlog_data["b1"]
    s1 = setup_backlog_data["s1"]

    # Viewer cannot add issues to backlog (403)
    resp_add_v = client.post(
        f"/api/v1/projects/{proj.id}/backlog/issues",
        headers=_auth_header(viewer),
        json={"issue_ids": [str(s1.id)]},
    )
    assert resp_add_v.status_code == 403

    # Member cannot delete from backlog (requires ISSUE_DELETE -> ADMIN) (403)
    resp_del_m = client.delete(
        f"/api/v1/projects/{proj.id}/backlog/issues/{b1.id}",
        headers=_auth_header(m1),
    )
    assert resp_del_m.status_code == 403

    # Outsider cannot view backlog (404)
    resp_outsider = client.get(
        f"/api/v1/projects/{proj.id}/backlog",
        headers=_auth_header(outsider),
    )
    assert resp_outsider.status_code == 404

    # Unauthenticated cannot view (401)
    resp_unauth = client.get(f"/api/v1/projects/{proj.id}/backlog")
    assert resp_unauth.status_code == 401
