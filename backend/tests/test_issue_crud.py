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
def setup_project_data(db_session):
    ws_owner = _create_user(db_session, "ws_owner@example.com", "Workspace Owner")
    proj_admin = _create_user(db_session, "proj_admin@example.com", "Project Admin")
    proj_member = _create_user(db_session, "proj_member@example.com", "Project Member")
    proj_viewer = _create_user(db_session, "proj_viewer@example.com", "Project Viewer")
    ws_only_user = _create_user(db_session, "ws_only@example.com", "Workspace Only")
    outsider = _create_user(db_session, "outsider@example.com", "Outsider")

    ws = Workspace(name="Core Workspace", slug="core-ws", owner_id=ws_owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.refresh(ws)

    db_session.add_all(
        [
            WorkspaceMember(
                workspace_id=ws.id, user_id=ws_owner.id, role=RoleType.OWNER
            ),
            WorkspaceMember(
                workspace_id=ws.id, user_id=proj_admin.id, role=RoleType.MEMBER
            ),
            WorkspaceMember(
                workspace_id=ws.id, user_id=proj_member.id, role=RoleType.MEMBER
            ),
            WorkspaceMember(
                workspace_id=ws.id, user_id=proj_viewer.id, role=RoleType.MEMBER
            ),
            WorkspaceMember(
                workspace_id=ws.id, user_id=ws_only_user.id, role=RoleType.MEMBER
            ),
        ]
    )
    db_session.commit()

    proj = Project(name="Project Alpha", key="ALPHA", workspace_id=ws.id)
    proj2 = Project(name="Project Beta", key="BETA", workspace_id=ws.id)
    db_session.add_all([proj, proj2])
    db_session.commit()
    db_session.refresh(proj)
    db_session.refresh(proj2)

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
            ProjectMember(
                project_id=proj2.id, user_id=proj_admin.id, role=RoleType.ADMIN
            ),
        ]
    )
    db_session.commit()

    return {
        "workspace": ws,
        "project": proj,
        "project2": proj2,
        "ws_owner": ws_owner,
        "proj_admin": proj_admin,
        "proj_member": proj_member,
        "proj_viewer": proj_viewer,
        "ws_only_user": ws_only_user,
        "outsider": outsider,
    }


# ---------------------------------------------------------------------------
# Issue Creation Tests
# ---------------------------------------------------------------------------
def test_create_issue_success_auto_increment(client, setup_project_data):
    """Member creates issue via project endpoint, auto-assigns sequential issue_numbers."""
    proj = setup_project_data["project"]
    member = setup_project_data["proj_member"]

    # First issue -> issue_number = 1
    resp1 = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={
            "title": "First Issue",
            "description": "Initial task description",
            "type": "task",
            "priority": "high",
        },
    )
    assert resp1.status_code == 201
    data1 = resp1.json()
    assert data1["issue_number"] == 1
    assert data1["title"] == "First Issue"
    assert data1["status"] == "backlog"
    assert data1["priority"] == "high"
    assert data1["reporter_id"] == str(member.id)
    assert data1["project_id"] == str(proj.id)

    # Second issue -> issue_number = 2
    resp2 = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={"title": "Second Issue"},
    )
    assert resp2.status_code == 201
    data2 = resp2.json()
    assert data2["issue_number"] == 2


def test_create_issue_explicit_issue_number_and_duplicate_rejection(
    client, setup_project_data
):
    """Explicit issue_number is allowed, duplicate raises 409 Conflict."""
    proj = setup_project_data["project"]
    member = setup_project_data["proj_member"]

    resp1 = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={"title": "Explicit Issue", "issue_number": 10},
    )
    assert resp1.status_code == 201
    assert resp1.json()["issue_number"] == 10

    # Duplicate issue_number in same project
    resp2 = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={"title": "Duplicate Issue", "issue_number": 10},
    )
    assert resp2.status_code == 409
    assert "already exists" in resp2.json()["detail"]


def test_create_issue_via_root_endpoint(client, setup_project_data):
    """POST /api/v1/issues creates issue when project_id is in body."""
    proj = setup_project_data["project"]
    member = setup_project_data["proj_member"]

    resp = client.post(
        "/api/v1/issues",
        headers=_auth_header(member),
        json={"project_id": str(proj.id), "title": "Root Endpoint Issue"},
    )
    assert resp.status_code == 201
    assert resp.json()["title"] == "Root Endpoint Issue"

    # Missing project_id in body returns 422
    resp_no_proj = client.post(
        "/api/v1/issues",
        headers=_auth_header(member),
        json={"title": "Missing Project ID"},
    )
    assert resp_no_proj.status_code == 422


def test_create_issue_validation_failures(client, setup_project_data):
    """Blank title or invalid values return 422 Unprocessable Entity."""
    proj = setup_project_data["project"]
    member = setup_project_data["proj_member"]

    # Blank title
    resp = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={"title": "   "},
    )
    assert resp.status_code == 422

    # Issue number <= 0
    resp_num = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={"title": "Valid Title", "issue_number": 0},
    )
    assert resp_num.status_code == 422


def test_create_issue_permissions(client, setup_project_data):
    """Viewer cannot create issue (403), outsider gets 404."""
    proj = setup_project_data["project"]
    viewer = setup_project_data["proj_viewer"]
    outsider = setup_project_data["outsider"]

    # Viewer gets 403
    resp_v = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(viewer),
        json={"title": "Viewer Issue Attempt"},
    )
    assert resp_v.status_code == 403

    # Outsider gets 404
    resp_o = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(outsider),
        json={"title": "Outsider Issue Attempt"},
    )
    assert resp_o.status_code == 404


# ---------------------------------------------------------------------------
# Assignee Validation Tests
# ---------------------------------------------------------------------------
def test_create_issue_assignee_validation(client, setup_project_data):
    """Assignee must be an active project member, non-members return 400."""
    proj = setup_project_data["project"]
    admin = setup_project_data["proj_admin"]
    member = setup_project_data["proj_member"]
    ws_only = setup_project_data["ws_only_user"]

    # Valid assignee (project member)
    resp_ok = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(admin),
        json={"title": "Assigned Issue", "assignee_id": str(member.id)},
    )
    assert resp_ok.status_code == 201
    assert resp_ok.json()["assignee_id"] == str(member.id)

    # Invalid assignee (user belongs to workspace but NOT project) -> 400
    resp_bad = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(admin),
        json={"title": "Bad Assignee Issue", "assignee_id": str(ws_only.id)},
    )
    assert resp_bad.status_code == 400
    assert "Assignee must be a member of the project" in resp_bad.json()["detail"]


# ---------------------------------------------------------------------------
# Parent-Child Hierarchy Tests
# ---------------------------------------------------------------------------
def test_issue_parent_child_hierarchy(client, setup_project_data):
    """Support parent-child issues, subtasks, and sub-issues listing."""
    proj = setup_project_data["project"]
    member = setup_project_data["proj_member"]

    # 1. Create Parent Epic
    resp_parent = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={"title": "Epic: Authentication", "type": "epic"},
    )
    assert resp_parent.status_code == 201
    parent_id = resp_parent.json()["id"]

    # 2. Create Child Task
    resp_child = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={
            "title": "Task: Login Endpoint",
            "type": "task",
            "parent_id": parent_id,
        },
    )
    assert resp_child.status_code == 201
    child_data = resp_child.json()
    assert child_data["parent_id"] == parent_id
    assert child_data["parent"]["id"] == parent_id
    assert child_data["parent"]["title"] == "Epic: Authentication"

    # 3. Create Subtask with parent
    resp_subtask = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={
            "title": "Subtask: Unit Tests",
            "type": "subtask",
            "parent_id": parent_id,
        },
    )
    assert resp_subtask.status_code == 201
    subtask_id = resp_subtask.json()["id"]

    # 4. Creating Subtask WITHOUT parent raises 400
    resp_orphan_subtask = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={"title": "Orphan Subtask", "type": "subtask"},
    )
    assert resp_orphan_subtask.status_code == 400
    assert "A subtask must have a parent issue" in resp_orphan_subtask.json()["detail"]

    # 5. Subtask cannot have children
    resp_subtask_child = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={"title": "Child of Subtask", "parent_id": subtask_id},
    )
    assert resp_subtask_child.status_code == 400
    assert "A subtask cannot have child issues" in resp_subtask_child.json()["detail"]

    # 6. List sub-issues endpoint
    resp_list_sub = client.get(
        f"/api/v1/issues/{parent_id}/sub-issues",
        headers=_auth_header(member),
    )
    assert resp_list_sub.status_code == 200
    sub_items = resp_list_sub.json()
    assert len(sub_items) == 2
    sub_titles = [i["title"] for i in sub_items]
    assert "Task: Login Endpoint" in sub_titles
    assert "Subtask: Unit Tests" in sub_titles


def test_parent_in_different_project_rejected(client, setup_project_data):
    """Parent issue must belong to the same project (returns 400)."""
    proj = setup_project_data["project"]
    proj2 = setup_project_data["project2"]
    admin = setup_project_data["proj_admin"]

    # Create issue in Project Beta
    resp_p2 = client.post(
        f"/api/v1/projects/{proj2.id}/issues",
        headers=_auth_header(admin),
        json={"title": "Beta Issue"},
    )
    assert resp_p2.status_code == 201
    p2_issue_id = resp_p2.json()["id"]

    # Attempt to link in Project Alpha to Project Beta issue
    resp = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(admin),
        json={"title": "Cross Project Child", "parent_id": p2_issue_id},
    )
    assert resp.status_code == 400
    assert "Parent issue must belong to the same project" in resp.json()["detail"]


# ---------------------------------------------------------------------------
# Read and List Tests
# ---------------------------------------------------------------------------
def test_get_issue_by_id(client, setup_project_data):
    """Retrieve issue details by ID; verify permissions."""
    proj = setup_project_data["project"]
    member = setup_project_data["proj_member"]
    viewer = setup_project_data["proj_viewer"]
    ws_owner = setup_project_data["ws_owner"]
    outsider = setup_project_data["outsider"]

    resp_create = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={"title": "Fetchable Issue", "description": "Details here"},
    )
    assert resp_create.status_code == 201
    issue_id = resp_create.json()["id"]

    # Member can read
    resp_m = client.get(f"/api/v1/issues/{issue_id}", headers=_auth_header(member))
    assert resp_m.status_code == 200
    assert resp_m.json()["title"] == "Fetchable Issue"

    # Viewer can read
    resp_v = client.get(f"/api/v1/issues/{issue_id}", headers=_auth_header(viewer))
    assert resp_v.status_code == 200

    # Workspace Owner can read via inheritance
    resp_o = client.get(f"/api/v1/issues/{issue_id}", headers=_auth_header(ws_owner))
    assert resp_o.status_code == 200

    # Outsider gets 404
    resp_out = client.get(f"/api/v1/issues/{issue_id}", headers=_auth_header(outsider))
    assert resp_out.status_code == 404


def test_list_project_issues_pagination(client, setup_project_data):
    """Paginated list of issues in a project."""
    proj = setup_project_data["project"]
    member = setup_project_data["proj_member"]
    viewer = setup_project_data["proj_viewer"]

    for i in range(5):
        client.post(
            f"/api/v1/projects/{proj.id}/issues",
            headers=_auth_header(member),
            json={"title": f"Batch Issue {i + 1}"},
        )

    # Page 1, size 2
    resp1 = client.get(
        f"/api/v1/projects/{proj.id}/issues?page=1&page_size=2",
        headers=_auth_header(viewer),
    )
    assert resp1.status_code == 200
    data1 = resp1.json()
    assert data1["total"] == 5
    assert data1["page"] == 1
    assert data1["page_size"] == 2
    assert data1["total_pages"] == 3
    assert len(data1["items"]) == 2

    # Page 3, size 2 (should have 1 item)
    resp3 = client.get(
        f"/api/v1/projects/{proj.id}/issues?page=3&page_size=2",
        headers=_auth_header(viewer),
    )
    assert resp3.status_code == 200
    assert len(resp3.json()["items"]) == 1


# ---------------------------------------------------------------------------
# Update Issue Tests
# ---------------------------------------------------------------------------
def test_update_issue_attributes(client, setup_project_data):
    """Update title, description, priority, status of an issue."""
    proj = setup_project_data["project"]
    member = setup_project_data["proj_member"]

    resp = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={"title": "Original Title", "priority": "low", "status": "todo"},
    )
    issue_id = resp.json()["id"]

    resp_up = client.patch(
        f"/api/v1/issues/{issue_id}",
        headers=_auth_header(member),
        json={
            "title": "Updated Title",
            "priority": "urgent",
            "status": "in_progress",
            "description": "Updated details",
        },
    )
    assert resp_up.status_code == 200
    updated = resp_up.json()
    assert updated["title"] == "Updated Title"
    assert updated["priority"] == "urgent"
    assert updated["status"] == "in_progress"
    assert updated["description"] == "Updated details"


def test_update_issue_circular_hierarchy_rejected(client, setup_project_data):
    """Setting parent to self or causing circular reference returns 400."""
    proj = setup_project_data["project"]
    member = setup_project_data["proj_member"]

    resp_a = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={"title": "Issue A"},
    )
    id_a = resp_a.json()["id"]

    resp_b = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={"title": "Issue B", "parent_id": id_a},
    )
    id_b = resp_b.json()["id"]

    # 1. Self as parent
    resp_self = client.patch(
        f"/api/v1/issues/{id_a}",
        headers=_auth_header(member),
        json={"parent_id": id_a},
    )
    assert resp_self.status_code == 400
    assert "An issue cannot be its own parent" in resp_self.json()["detail"]

    # 2. Circular reference: A -> B -> A
    resp_circle = client.patch(
        f"/api/v1/issues/{id_a}",
        headers=_auth_header(member),
        json={"parent_id": id_b},
    )
    assert resp_circle.status_code == 400
    assert "Circular parent-child relationship detected" in resp_circle.json()["detail"]


def test_update_issue_assignee(client, setup_project_data):
    """Update assignee to member, invalid user returns 400, None unassigns."""
    proj = setup_project_data["project"]
    member = setup_project_data["proj_member"]
    admin = setup_project_data["proj_admin"]
    outsider = setup_project_data["outsider"]

    resp = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={"title": "Assignee Test"},
    )
    issue_id = resp.json()["id"]

    # Assign to admin (valid)
    resp_assign = client.patch(
        f"/api/v1/issues/{issue_id}",
        headers=_auth_header(member),
        json={"assignee_id": str(admin.id)},
    )
    assert resp_assign.status_code == 200
    assert resp_assign.json()["assignee_id"] == str(admin.id)

    # Assign to outsider (invalid) -> 400
    resp_bad = client.patch(
        f"/api/v1/issues/{issue_id}",
        headers=_auth_header(member),
        json={"assignee_id": str(outsider.id)},
    )
    assert resp_bad.status_code == 400

    # Unassign (None)
    resp_none = client.patch(
        f"/api/v1/issues/{issue_id}",
        headers=_auth_header(member),
        json={"assignee_id": None},
    )
    assert resp_none.status_code == 200
    assert resp_none.json()["assignee_id"] is None


def test_update_issue_permission_forbidden(client, setup_project_data):
    """Viewer cannot update an issue (403 Forbidden)."""
    proj = setup_project_data["project"]
    member = setup_project_data["proj_member"]
    viewer = setup_project_data["proj_viewer"]

    resp = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(member),
        json={"title": "Permissions Issue"},
    )
    issue_id = resp.json()["id"]

    resp_v = client.patch(
        f"/api/v1/issues/{issue_id}",
        headers=_auth_header(viewer),
        json={"title": "Viewer Edit Attempt"},
    )
    assert resp_v.status_code == 403


# ---------------------------------------------------------------------------
# Delete and Restore Tests
# ---------------------------------------------------------------------------
def test_delete_and_restore_issue(client, setup_project_data):
    """Soft delete requires ADMIN role, cascades to subtasks, restore restores them."""
    proj = setup_project_data["project"]
    admin = setup_project_data["proj_admin"]
    member = setup_project_data["proj_member"]

    # Create parent issue with child subtask
    resp_parent = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(admin),
        json={"title": "Parent Issue to Delete"},
    )
    parent_id = resp_parent.json()["id"]

    resp_child = client.post(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(admin),
        json={"title": "Child Subtask", "type": "subtask", "parent_id": parent_id},
    )
    child_id = resp_child.json()["id"]

    # Member cannot delete (requires ISSUE_DELETE -> ADMIN)
    resp_del_m = client.delete(
        f"/api/v1/issues/{parent_id}",
        headers=_auth_header(member),
    )
    assert resp_del_m.status_code == 403

    # Admin deletes parent
    resp_del = client.delete(
        f"/api/v1/issues/{parent_id}",
        headers=_auth_header(admin),
    )
    assert resp_del.status_code == 204

    # Both parent and child return 404
    assert (
        client.get(
            f"/api/v1/issues/{parent_id}", headers=_auth_header(admin)
        ).status_code
        == 404
    )
    assert (
        client.get(
            f"/api/v1/issues/{child_id}", headers=_auth_header(admin)
        ).status_code
        == 404
    )

    # Neither appears in project issues list
    resp_list = client.get(
        f"/api/v1/projects/{proj.id}/issues",
        headers=_auth_header(admin),
    )
    assert resp_list.status_code == 200
    listed_ids = [i["id"] for i in resp_list.json()["items"]]
    assert parent_id not in listed_ids
    assert child_id not in listed_ids

    # Restore parent issue
    resp_restore = client.post(
        f"/api/v1/issues/{parent_id}/restore",
        headers=_auth_header(admin),
    )
    assert resp_restore.status_code == 200
    assert resp_restore.json()["id"] == parent_id

    # Now both are active again
    assert (
        client.get(
            f"/api/v1/issues/{parent_id}", headers=_auth_header(admin)
        ).status_code
        == 200
    )
    assert (
        client.get(
            f"/api/v1/issues/{child_id}", headers=_auth_header(admin)
        ).status_code
        == 200
    )

    # Restoring an active issue returns 400
    resp_restore_again = client.post(
        f"/api/v1/issues/{parent_id}/restore",
        headers=_auth_header(admin),
    )
    assert resp_restore_again.status_code == 400
    assert "Issue is not deleted" in resp_restore_again.json()["detail"]
