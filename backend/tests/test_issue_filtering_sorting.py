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
def setup_filter_data(db_session):
    # Users
    ws_owner = _create_user(db_session, "ws_owner@example.com", "Workspace Owner")
    proj_admin = _create_user(db_session, "admin@example.com", "Project Admin")
    m1 = _create_user(db_session, "member1@example.com", "Member 1")
    m2 = _create_user(db_session, "member2@example.com", "Member 2")
    viewer = _create_user(db_session, "viewer@example.com", "Viewer")
    outsider = _create_user(db_session, "outsider@example.com", "Outsider")

    # Workspace
    ws = Workspace(name="Filter Workspace", slug="filter-ws", owner_id=ws_owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.refresh(ws)

    # Workspace Members
    for u, r in [
        (ws_owner, RoleType.OWNER),
        (proj_admin, RoleType.ADMIN),
        (m1, RoleType.MEMBER),
        (m2, RoleType.MEMBER),
        (viewer, RoleType.VIEWER),
    ]:
        db_session.add(WorkspaceMember(workspace_id=ws.id, user_id=u.id, role=r))
    db_session.commit()

    # Project
    proj = Project(
        workspace_id=ws.id,
        name="Filter Project",
        key="FLP",
    )
    db_session.add(proj)
    db_session.commit()
    db_session.refresh(proj)

    # Project Members
    for u, r in [
        (proj_admin, RoleType.ADMIN),
        (m1, RoleType.MEMBER),
        (m2, RoleType.MEMBER),
        (viewer, RoleType.VIEWER),
    ]:
        db_session.add(ProjectMember(project_id=proj.id, user_id=u.id, role=r))
    db_session.commit()

    # Sprints
    sprint1 = Sprint(project_id=proj.id, name="Sprint 1")
    sprint2 = Sprint(project_id=proj.id, name="Sprint 2")
    db_session.add_all([sprint1, sprint2])
    db_session.commit()
    db_session.refresh(sprint1)
    db_session.refresh(sprint2)

    # Seed 6 distinct issues for comprehensive filtering/sorting verification:
    # 1. Bug, Todo, Urgent, m1, sprint1
    # 2. Task, In Progress, High, m1, sprint1
    # 3. Story, Backlog, Low, m2, None
    # 4. Task, Done, High, m2, sprint2
    # 5. Task, Todo, Medium, Unassigned, sprint1
    # 6. Task, Canceled, Lowest, Unassigned, None
    issues_data = [
        Issue(
            project_id=proj.id,
            issue_number=1,
            title="Fix authentication login bug",
            description="Users face crash during token refresh",
            type=IssueType.BUG,
            status=IssueStatus.TODO,
            priority=IssuePriority.URGENT,
            reporter_id=proj_admin.id,
            assignee_id=m1.id,
            sprint_id=sprint1.id,
            backlog_rank=10.0,
        ),
        Issue(
            project_id=proj.id,
            issue_number=2,
            title="Implement dark mode toggle",
            description="Add theme switcher to navbar",
            type=IssueType.TASK,
            status=IssueStatus.IN_PROGRESS,
            priority=IssuePriority.HIGH,
            reporter_id=proj_admin.id,
            assignee_id=m1.id,
            sprint_id=sprint1.id,
            backlog_rank=20.0,
        ),
        Issue(
            project_id=proj.id,
            issue_number=3,
            title="Update documentation guides",
            description="Write API usage examples",
            type=IssueType.STORY,
            status=IssueStatus.BACKLOG,
            priority=IssuePriority.LOW,
            reporter_id=proj_admin.id,
            assignee_id=m2.id,
            sprint_id=None,
            backlog_rank=30.0,
        ),
        Issue(
            project_id=proj.id,
            issue_number=4,
            title="Database connection pooling",
            description="Tune pool size and recycling",
            type=IssueType.TASK,
            status=IssueStatus.DONE,
            priority=IssuePriority.HIGH,
            reporter_id=proj_admin.id,
            assignee_id=m2.id,
            sprint_id=sprint2.id,
            backlog_rank=40.0,
        ),
        Issue(
            project_id=proj.id,
            issue_number=5,
            title="Refactor notification service",
            description="Use asynchronous event queues",
            type=IssueType.TASK,
            status=IssueStatus.TODO,
            priority=IssuePriority.MEDIUM,
            reporter_id=proj_admin.id,
            assignee_id=None,
            sprint_id=sprint1.id,
            backlog_rank=50.0,
        ),
        Issue(
            project_id=proj.id,
            issue_number=6,
            title="Canceled obsolete feature",
            description="Old export format deprecation",
            type=IssueType.TASK,
            status=IssueStatus.CANCELED,
            priority=IssuePriority.LOWEST,
            reporter_id=proj_admin.id,
            assignee_id=None,
            sprint_id=None,
            backlog_rank=60.0,
        ),
    ]
    for issue in issues_data:
        db_session.add(issue)
    db_session.commit()

    return {
        "workspace": ws,
        "project": proj,
        "admin": proj_admin,
        "m1": m1,
        "m2": m2,
        "viewer": viewer,
        "outsider": outsider,
        "sprint1": sprint1,
        "sprint2": sprint2,
    }


# ---------------------------------------------------------------------------
# Filter Tests
# ---------------------------------------------------------------------------
def test_filter_by_single_status(client, setup_filter_data):
    """Filter by single status returns only matching issues."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/issues?status=todo",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 2
    assert {item["issue_number"] for item in data["items"]} == {1, 5}
    for item in data["items"]:
        assert item["status"] == "todo"


def test_filter_by_multiple_statuses_repeatable(client, setup_filter_data):
    """Filter by multiple statuses using repeated query parameters."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/issues?status=todo&status=in_progress",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 3
    assert {item["issue_number"] for item in data["items"]} == {1, 2, 5}


def test_filter_by_multiple_statuses_comma_separated(client, setup_filter_data):
    """Filter by multiple statuses using comma-separated values."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/issues?status=backlog,done,canceled",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 3
    assert {item["issue_number"] for item in data["items"]} == {3, 4, 6}


def test_filter_by_invalid_status_returns_422(client, setup_filter_data):
    """Invalid status value returns HTTP 422 Unprocessable Content."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/issues?status=unknown_status",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 422
    assert "Invalid issue status" in resp.json()["detail"]


def test_filter_by_assignee_id(client, setup_filter_data):
    """Filter by assignee user ID returns issues assigned to that specific user."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]
    m1 = setup_filter_data["m1"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/issues?assignee_id={m1.id}",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 2
    assert {item["issue_number"] for item in data["items"]} == {1, 2}
    for item in data["items"]:
        assert item["assignee_id"] == str(m1.id)


def test_filter_by_assignee_unassigned(client, setup_filter_data):
    """Filter by assignee='unassigned' returns only unassigned issues."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/issues?assignee=unassigned",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 2
    assert {item["issue_number"] for item in data["items"]} == {5, 6}
    for item in data["items"]:
        assert item["assignee_id"] is None


def test_filter_by_invalid_assignee_returns_422(client, setup_filter_data):
    """Non-UUID and non-unassigned assignee string returns 422."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/issues?assignee=not-a-valid-uuid",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 422


def test_filter_by_priority(client, setup_filter_data):
    """Filter by single and multiple priorities."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    # Single priority
    resp1 = client.get(
        f"/api/v1/projects/{proj.id}/issues?priority=urgent",
        headers=_auth_header(viewer),
    )
    assert resp1.status_code == 200
    data1 = resp1.json()
    assert data1["total"] == 1
    assert data1["items"][0]["issue_number"] == 1

    # Multiple priorities (comma-separated)
    resp2 = client.get(
        f"/api/v1/projects/{proj.id}/issues?priority=high,urgent",
        headers=_auth_header(viewer),
    )
    assert resp2.status_code == 200
    data2 = resp2.json()
    assert data2["total"] == 3
    assert {item["issue_number"] for item in data2["items"]} == {1, 2, 4}


def test_filter_by_invalid_priority_returns_422(client, setup_filter_data):
    """Invalid priority value returns 422."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/issues?priority=critical",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 422
    assert "Invalid issue priority" in resp.json()["detail"]


def test_filter_by_sprint_id_and_backlog(client, setup_filter_data):
    """Filter by sprint ID and unassigned sprint ('backlog'/'none')."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]
    sprint1 = setup_filter_data["sprint1"]

    # In sprint 1: issues 1, 2, 5
    resp1 = client.get(
        f"/api/v1/projects/{proj.id}/issues?sprint_id={sprint1.id}",
        headers=_auth_header(viewer),
    )
    assert resp1.status_code == 200
    data1 = resp1.json()
    assert data1["total"] == 3
    assert {item["issue_number"] for item in data1["items"]} == {1, 2, 5}

    # In backlog (no sprint assigned): issues 3, 6
    resp_backlog = client.get(
        f"/api/v1/projects/{proj.id}/issues?sprint=backlog",
        headers=_auth_header(viewer),
    )
    assert resp_backlog.status_code == 200
    data_backlog = resp_backlog.json()
    assert data_backlog["total"] == 2
    assert {item["issue_number"] for item in data_backlog["items"]} == {3, 6}


def test_filter_by_invalid_sprint_returns_422(client, setup_filter_data):
    """Non-UUID and non-backlog sprint string returns 422."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/issues?sprint=invalid-sprint",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 422


def test_filter_by_type_and_search(client, setup_filter_data):
    """Filter by issue type and search text in title/description."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    # Filter by type: bug (issue 1)
    resp_type = client.get(
        f"/api/v1/projects/{proj.id}/issues?type=bug",
        headers=_auth_header(viewer),
    )
    assert resp_type.status_code == 200
    assert resp_type.json()["total"] == 1
    assert resp_type.json()["items"][0]["issue_number"] == 1

    # Search keyword in title or description
    resp_search = client.get(
        f"/api/v1/projects/{proj.id}/issues?search=notification",
        headers=_auth_header(viewer),
    )
    assert resp_search.status_code == 200
    assert resp_search.json()["total"] == 1
    assert resp_search.json()["items"][0]["issue_number"] == 5


# ---------------------------------------------------------------------------
# Acceptance Criteria: Combined Multi-Filter Test
# ---------------------------------------------------------------------------
def test_combined_multi_filters(client, setup_filter_data):
    """
    Acceptance Criteria: 'Kết hợp nhiều filter trả kết quả đúng'.
    Combining status, priority, assignee_id, and sprint_id filters accurately.
    """
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]
    m1 = setup_filter_data["m1"]
    sprint1 = setup_filter_data["sprint1"]

    # Match issue 1 only (TODO, URGENT, m1, sprint1)
    resp = client.get(
        f"/api/v1/projects/{proj.id}/issues"
        f"?status=todo&priority=urgent&assignee_id={m1.id}&sprint_id={sprint1.id}",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 1
    assert len(data["items"]) == 1
    assert data["items"][0]["issue_number"] == 1

    # Conflict condition (TODO status but assigned to m2 who has no TODO issues) -> total 0
    m2 = setup_filter_data["m2"]
    resp_none = client.get(
        f"/api/v1/projects/{proj.id}/issues?status=todo&assignee_id={m2.id}",
        headers=_auth_header(viewer),
    )
    assert resp_none.status_code == 200
    assert resp_none.json()["total"] == 0
    assert len(resp_none.json()["items"]) == 0


# ---------------------------------------------------------------------------
# Multi-Field Sorting Tests
# ---------------------------------------------------------------------------
def test_multi_field_sorting_with_directions(client, setup_filter_data):
    """Sort by priority:desc,created_at:asc ensures higher priorities first, tie broken by created_at."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/issues?sort=priority:desc,issue_number:asc",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 200
    data = resp.json()
    items = data["items"]
    assert len(items) == 6

    # Expected order:
    # 1. urgent (Issue 1)
    # 2. high (Issue 2 and 4, tie broken by issue_number:asc -> 2, then 4)
    # 3. medium (Issue 5)
    # 4. low (Issue 3)
    # 5. lowest (Issue 6)
    numbers = [i["issue_number"] for i in items]
    assert numbers == [1, 2, 4, 5, 3, 6]


def test_multi_field_sorting_with_dash_syntax(client, setup_filter_data):
    """Sort using '-priority,title:asc' format."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/issues?sort=-priority,title:asc",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 200
    items = resp.json()["items"]

    # Issue 1 (urgent) first.
    # Among HIGH: Issue 4 ("Database connection pooling") precedes Issue 2 ("Implement dark mode toggle") alphabetically.
    numbers = [i["issue_number"] for i in items]
    assert numbers[0] == 1
    assert numbers[1] == 4
    assert numbers[2] == 2


def test_single_field_sorting_via_sort_by_and_order(client, setup_filter_data):
    """Sort using sort_by and order query parameters."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    # Priority ascending (lowest to urgent)
    resp_asc = client.get(
        f"/api/v1/projects/{proj.id}/issues?sort_by=priority&order=asc",
        headers=_auth_header(viewer),
    )
    assert resp_asc.status_code == 200
    items_asc = resp_asc.json()["items"]
    assert items_asc[0]["issue_number"] == 6  # lowest
    assert items_asc[-1]["issue_number"] == 1  # urgent

    # Title descending
    resp_desc = client.get(
        f"/api/v1/projects/{proj.id}/issues?sort_by=title&order=desc",
        headers=_auth_header(viewer),
    )
    assert resp_desc.status_code == 200
    titles = [i["title"] for i in resp_desc.json()["items"]]
    assert titles == sorted(titles, reverse=True)


def test_invalid_sort_field_returns_422(client, setup_filter_data):
    """Unknown sort field returns HTTP 422."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/issues?sort=unsupported_col:desc",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 422
    assert "Invalid sort field" in resp.json()["detail"]


def test_invalid_sort_direction_returns_422(client, setup_filter_data):
    """Invalid sort direction returns HTTP 422."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/issues?sort=priority:sideways",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 422
    assert "Invalid sort direction" in resp.json()["detail"]


# ---------------------------------------------------------------------------
# Pagination Tests (Offset & Cursor)
# ---------------------------------------------------------------------------
def test_offset_pagination(client, setup_filter_data):
    """Standard offset pagination using page and page_size."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    # Page 1, size 2
    r1 = client.get(
        f"/api/v1/projects/{proj.id}/issues?page=1&page_size=2",
        headers=_auth_header(viewer),
    )
    assert r1.status_code == 200
    d1 = r1.json()
    assert d1["total"] == 6
    assert d1["page"] == 1
    assert d1["page_size"] == 2
    assert d1["total_pages"] == 3
    assert len(d1["items"]) == 2
    assert d1["has_more"] is True
    assert d1["next_cursor"] is not None

    # Page 3, size 2 (last page)
    r3 = client.get(
        f"/api/v1/projects/{proj.id}/issues?page=3&page_size=2",
        headers=_auth_header(viewer),
    )
    assert r3.status_code == 200
    d3 = r3.json()
    assert d3["page"] == 3
    assert len(d3["items"]) == 2
    assert d3["has_more"] is False
    assert d3["next_cursor"] is None


def test_cursor_pagination_flow(client, setup_filter_data):
    """Cursor-based pagination correctly iterates all pages without gaps or duplication."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    collected_issue_numbers = []
    cursor = None

    for _ in range(5):  # Safety bound
        url = f"/api/v1/projects/{proj.id}/issues?page_size=2"
        if cursor:
            url += f"&cursor={cursor}"

        resp = client.get(url, headers=_auth_header(viewer))
        assert resp.status_code == 200
        data = resp.json()

        for item in data["items"]:
            collected_issue_numbers.append(item["issue_number"])

        cursor = data.get("next_cursor")
        if not data.get("has_more"):
            break

    # All 6 issues collected in correct sequential order
    assert len(collected_issue_numbers) == 6
    assert len(set(collected_issue_numbers)) == 6
    assert collected_issue_numbers == [1, 2, 3, 4, 5, 6]


def test_invalid_cursor_returns_422(client, setup_filter_data):
    """Malformed cursor string returns HTTP 422."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    resp = client.get(
        f"/api/v1/projects/{proj.id}/issues?cursor=not-a-valid-base64-json",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 422
    assert "Invalid pagination cursor" in resp.json()["detail"]


# ---------------------------------------------------------------------------
# Direct /api/v1/issues Endpoint & Permissions
# ---------------------------------------------------------------------------
def test_list_issues_direct_endpoint(client, setup_filter_data):
    """Direct GET /api/v1/issues endpoint functions with project_id and filters."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]

    # Missing project_id returns 422
    resp_missing = client.get(
        "/api/v1/issues",
        headers=_auth_header(viewer),
    )
    assert resp_missing.status_code == 422

    # With project_id and filter
    resp = client.get(
        f"/api/v1/issues?project_id={proj.id}&status=todo",
        headers=_auth_header(viewer),
    )
    assert resp.status_code == 200
    assert resp.json()["total"] == 2


def test_list_issues_permissions(client, setup_filter_data):
    """Viewer can list; outsider receives 404; unauthenticated receives 401."""
    proj = setup_filter_data["project"]
    viewer = setup_filter_data["viewer"]
    outsider = setup_filter_data["outsider"]

    # Viewer: 200 OK
    resp_viewer = client.get(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(viewer),
    )
    assert resp_viewer.status_code == 200

    # Outsider: 404 Not Found
    resp_outsider = client.get(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(outsider),
    )
    assert resp_outsider.status_code == 404

    # Direct endpoint with outsider: 404 Not Found
    resp_outsider_direct = client.get(
        f"/api/v1/issues?project_id={proj.id}",
        headers=_auth_header(outsider),
    )
    assert resp_outsider_direct.status_code == 404

    # Unauthenticated: 401 Unauthorized
    resp_unauth = client.get(f"/api/v1/projects/{proj.id}/issues")
    assert resp_unauth.status_code == 401
