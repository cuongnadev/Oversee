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
def setup_planning_data(db_session):
    ws_owner = _create_user(db_session, "ws_owner@example.com", "Workspace Owner")
    proj_admin = _create_user(db_session, "admin@example.com", "Project Admin")
    m1 = _create_user(db_session, "member1@example.com", "Member 1")
    viewer = _create_user(db_session, "viewer@example.com", "Viewer")
    outsider = _create_user(db_session, "outsider@example.com", "Outsider")

    ws = Workspace(name="Planning Workspace", slug="planning-ws", owner_id=ws_owner.id)
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
        name="Planning Project",
        key="PLN",
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

    # Another project for boundary validation
    proj2 = Project(
        workspace_id=ws.id,
        name="Other Project",
        key="OTH",
    )
    db_session.add(proj2)
    db_session.commit()
    db_session.refresh(proj2)

    db_session.add(
        ProjectMember(project_id=proj2.id, user_id=m1.id, role=RoleType.MEMBER)
    )
    db_session.commit()

    sprint1 = Sprint(project_id=proj.id, name="Sprint 1", capacity=15.0)
    sprint2 = Sprint(project_id=proj.id, name="Sprint 2", capacity=10.0)
    db_session.add_all([sprint1, sprint2])
    db_session.commit()
    db_session.refresh(sprint1)
    db_session.refresh(sprint2)

    # Seed 3 issues in Project 1 (backlog)
    issue1 = Issue(
        project_id=proj.id,
        issue_number=1,
        title="Issue 1 - Feature A",
        type=IssueType.STORY,
        status=IssueStatus.BACKLOG,
        priority=IssuePriority.HIGH,
        reporter_id=proj_admin.id,
        estimate=5.0,
        sprint_id=None,
    )
    issue2 = Issue(
        project_id=proj.id,
        issue_number=2,
        title="Issue 2 - Feature B",
        type=IssueType.TASK,
        status=IssueStatus.BACKLOG,
        priority=IssuePriority.MEDIUM,
        reporter_id=proj_admin.id,
        estimate=8.0,
        sprint_id=None,
    )
    issue3 = Issue(
        project_id=proj.id,
        issue_number=3,
        title="Issue 3 - Bug Fix",
        type=IssueType.BUG,
        status=IssueStatus.BACKLOG,
        priority=IssuePriority.LOW,
        reporter_id=proj_admin.id,
        estimate=4.0,
        sprint_id=None,
    )

    # Seed 1 issue in Project 2
    issue_other = Issue(
        project_id=proj2.id,
        issue_number=1,
        title="Other Project Issue",
        type=IssueType.TASK,
        status=IssueStatus.BACKLOG,
        priority=IssuePriority.MEDIUM,
        reporter_id=m1.id,
        estimate=3.0,
        sprint_id=None,
    )

    db_session.add_all([issue1, issue2, issue3, issue_other])
    db_session.commit()
    db_session.refresh(issue1)
    db_session.refresh(issue2)
    db_session.refresh(issue3)
    db_session.refresh(issue_other)

    return {
        "admin": proj_admin,
        "member": m1,
        "viewer": viewer,
        "outsider": outsider,
        "project": proj,
        "project2": proj2,
        "sprint1": sprint1,
        "sprint2": sprint2,
        "issue1": issue1,
        "issue2": issue2,
        "issue3": issue3,
        "issue_other": issue_other,
    }


# ---------------------------------------------------------------------------
# Test Cases
# ---------------------------------------------------------------------------
def test_add_issues_to_sprint(client, setup_planning_data, db_session):
    """Assign multiple issues to a sprint and list them."""
    data = setup_planning_data
    sprint1_id = data["sprint1"].id
    i1_id = data["issue1"].id
    i2_id = data["issue2"].id

    payload = {"issue_ids": [str(i1_id), str(i2_id)]}
    resp = client.post(
        f"/api/v1/sprints/{sprint1_id}/issues",
        json=payload,
        headers=_auth_header(data["member"]),
    )
    assert resp.status_code == 200
    items = resp.json()
    assert len(items) == 2
    assert all(item["sprint_id"] == str(sprint1_id) for item in items)
    assert all(not item["is_backlog"] for item in items)

    # List sprint issues
    list_resp = client.get(
        f"/api/v1/sprints/{sprint1_id}/issues",
        headers=_auth_header(data["viewer"]),
    )
    assert list_resp.status_code == 200
    assert len(list_resp.json()) == 2


def test_add_single_issue_to_sprint(client, setup_planning_data, db_session):
    """Assign a single issue via path parameter."""
    data = setup_planning_data
    sprint1_id = data["sprint1"].id
    i3_id = data["issue3"].id

    resp = client.post(
        f"/api/v1/sprints/{sprint1_id}/issues/{i3_id}",
        headers=_auth_header(data["member"]),
    )
    assert resp.status_code == 200
    db_session.refresh(data["issue3"])
    assert data["issue3"].sprint_id == sprint1_id


def test_issue_belongs_to_at_most_one_sprint(client, setup_planning_data, db_session):
    """
    Acceptance Criteria: Issue chỉ thuộc tối đa một sprint.
    When moving an issue from Sprint 1 to Sprint 2, it leaves Sprint 1.
    """
    data = setup_planning_data
    sprint1_id = data["sprint1"].id
    sprint2_id = data["sprint2"].id
    i1_id = data["issue1"].id

    # 1. Assign to Sprint 1
    resp1 = client.post(
        f"/api/v1/sprints/{sprint1_id}/issues",
        json={"issue_ids": [str(i1_id)]},
        headers=_auth_header(data["member"]),
    )
    assert resp1.status_code == 200

    # Verify present in Sprint 1
    list1 = client.get(
        f"/api/v1/sprints/{sprint1_id}/issues",
        headers=_auth_header(data["viewer"]),
    ).json()
    assert len(list1) == 1
    assert list1[0]["id"] == str(i1_id)

    # 2. Reassign to Sprint 2
    resp2 = client.post(
        f"/api/v1/sprints/{sprint2_id}/issues",
        json={"issue_ids": [str(i1_id)]},
        headers=_auth_header(data["member"]),
    )
    assert resp2.status_code == 200

    # 3. Verify it moved: NOT in Sprint 1, now in Sprint 2
    list1_after = client.get(
        f"/api/v1/sprints/{sprint1_id}/issues",
        headers=_auth_header(data["viewer"]),
    ).json()
    assert len(list1_after) == 0

    list2 = client.get(
        f"/api/v1/sprints/{sprint2_id}/issues",
        headers=_auth_header(data["viewer"]),
    ).json()
    assert len(list2) == 1
    assert list2[0]["id"] == str(i1_id)
    assert list2[0]["sprint_id"] == str(sprint2_id)


def test_cannot_assign_issue_from_different_project(client, setup_planning_data):
    """Attempting to assign an issue from another project to a sprint fails with 400."""
    data = setup_planning_data
    sprint1_id = data["sprint1"].id
    other_issue_id = data["issue_other"].id

    resp = client.post(
        f"/api/v1/sprints/{sprint1_id}/issues",
        json={"issue_ids": [str(other_issue_id)]},
        headers=_auth_header(data["member"]),
    )
    assert resp.status_code == 400
    assert "does not belong to the sprint's project" in resp.json()["detail"]


def test_remove_issue_from_sprint(client, setup_planning_data, db_session):
    """Removing issue from sprint resets sprint_id to None (moves back to backlog)."""
    data = setup_planning_data
    sprint1_id = data["sprint1"].id
    i1_id = data["issue1"].id
    i2_id = data["issue2"].id

    # Add both to sprint
    client.post(
        f"/api/v1/sprints/{sprint1_id}/issues",
        json={"issue_ids": [str(i1_id), str(i2_id)]},
        headers=_auth_header(data["member"]),
    )

    # Remove i1 by single endpoint
    del_resp1 = client.delete(
        f"/api/v1/sprints/{sprint1_id}/issues/{i1_id}",
        headers=_auth_header(data["member"]),
    )
    assert del_resp1.status_code == 204

    db_session.refresh(data["issue1"])
    assert data["issue1"].sprint_id is None
    assert data["issue1"].is_backlog is True

    # Remove i2 by batch endpoint
    del_resp2 = client.request(
        "DELETE",
        f"/api/v1/sprints/{sprint1_id}/issues",
        json={"issue_ids": [str(i2_id)]},
        headers=_auth_header(data["member"]),
    )
    assert del_resp2.status_code == 204

    db_session.refresh(data["issue2"])
    assert data["issue2"].sprint_id is None

    # Sprint issues list is now empty
    list_resp = client.get(
        f"/api/v1/sprints/{sprint1_id}/issues",
        headers=_auth_header(data["viewer"]),
    )
    assert len(list_resp.json()) == 0


def test_remove_issue_not_in_sprint_fails(client, setup_planning_data):
    """Removing an issue that is not assigned to the sprint returns 400."""
    data = setup_planning_data
    sprint1_id = data["sprint1"].id
    i1_id = data["issue1"].id

    resp = client.delete(
        f"/api/v1/sprints/{sprint1_id}/issues/{i1_id}",
        headers=_auth_header(data["member"]),
    )
    assert resp.status_code == 400
    assert "not assigned to this sprint" in resp.json()["detail"]


def test_sprint_planning_estimate_and_capacity_warning(client, setup_planning_data):
    """
    Test total estimate aggregation and capacity limit warning:
    Sprint 2 has capacity = 10.0.
    - Adding issue 1 (5.0): total = 5.0, is_over_capacity = False
    - Adding issue 2 (8.0): total = 13.0, is_over_capacity = True, warning present
    """
    data = setup_planning_data
    sprint2_id = data["sprint2"].id
    i1_id = data["issue1"].id
    i2_id = data["issue2"].id

    # Initial planning summary: 0 issues, 0 estimate
    p0 = client.get(
        f"/api/v1/sprints/{sprint2_id}/planning",
        headers=_auth_header(data["viewer"]),
    ).json()
    assert p0["total_issues"] == 0
    assert p0["total_estimate"] == 0.0
    assert p0["capacity"] == 10.0
    assert p0["is_over_capacity"] is False
    assert p0["warning"] is None

    # Add Issue 1 (estimate = 5.0)
    client.post(
        f"/api/v1/sprints/{sprint2_id}/issues",
        json={"issue_ids": [str(i1_id)]},
        headers=_auth_header(data["member"]),
    )

    p1 = client.get(
        f"/api/v1/sprints/{sprint2_id}/planning",
        headers=_auth_header(data["viewer"]),
    ).json()
    assert p1["total_issues"] == 1
    assert p1["total_estimate"] == 5.0
    assert p1["is_over_capacity"] is False
    assert p1["warning"] is None

    # Add Issue 2 (estimate = 8.0) -> Total becomes 13.0 > 10.0
    client.post(
        f"/api/v1/sprints/{sprint2_id}/issues",
        json={"issue_ids": [str(i2_id)]},
        headers=_auth_header(data["member"]),
    )

    p2 = client.get(
        f"/api/v1/sprints/{sprint2_id}/planning",
        headers=_auth_header(data["viewer"]),
    ).json()
    assert p2["total_issues"] == 2
    assert p2["total_estimate"] == 13.0
    assert p2["is_over_capacity"] is True
    assert "exceeds planned capacity" in p2["warning"]


def test_sprint_planning_permissions(client, setup_planning_data):
    """Test RBAC for sprint planning: VIEWER cannot assign/remove, OUTSIDER gets 404."""
    data = setup_planning_data
    sprint1_id = data["sprint1"].id
    i1_id = data["issue1"].id

    # 1. VIEWER cannot assign issues -> 403
    resp_viewer = client.post(
        f"/api/v1/sprints/{sprint1_id}/issues",
        json={"issue_ids": [str(i1_id)]},
        headers=_auth_header(data["viewer"]),
    )
    assert resp_viewer.status_code == 403

    # 2. VIEWER cannot remove issues -> 403
    resp_viewer_del = client.delete(
        f"/api/v1/sprints/{sprint1_id}/issues/{i1_id}",
        headers=_auth_header(data["viewer"]),
    )
    assert resp_viewer_del.status_code == 403

    # 3. OUTSIDER gets 404 on planning endpoint
    resp_outsider = client.get(
        f"/api/v1/sprints/{sprint1_id}/planning",
        headers=_auth_header(data["outsider"]),
    )
    assert resp_outsider.status_code == 404

    # 4. Unauthenticated gets 401
    resp_unauth = client.get(f"/api/v1/sprints/{sprint1_id}/planning")
    assert resp_unauth.status_code == 401
