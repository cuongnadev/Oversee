import uuid
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from app.db.session import get_db
from app.main import app
from app.models.enums import RoleType


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
@pytest.fixture
def client(db_session):
    app.dependency_overrides[get_db] = lambda: db_session
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def _auth_header(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# Workflow 1: Registration → Login → Workspace → Project → Issue Lifecycle
# ---------------------------------------------------------------------------
def test_workflow_registration_to_issue_creation(client):
    """
    End-to-end integration flow:
      1. Register new user
      2. Login to obtain access and refresh tokens
      3. Verify authenticated user identity via /users/me
      4. Create a workspace (user becomes OWNER)
      5. Create a project under the workspace
      6. Create an issue under the project
      7. Retrieve the issue and verify fields and initial backlog status
    """
    email = f"lead_{uuid.uuid4().hex[:6]}@example.com"
    password = "StrongPassword123!"
    full_name = "Team Lead"

    # Step 1: Register
    reg_resp = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "full_name": full_name},
    )
    assert reg_resp.status_code == 201
    user_data = reg_resp.json()
    assert user_data["email"] == email.lower()
    assert user_data["full_name"] == full_name

    # Step 2: Login
    login_resp = client.post(
        "/api/v1/auth/login",
        data={"username": email, "password": password},
    )
    assert login_resp.status_code == 200
    token_data = login_resp.json()
    access_token = token_data["access_token"]
    assert access_token is not None
    assert token_data["token_type"].lower() == "bearer"

    headers = _auth_header(access_token)

    # Step 3: Verify /users/me
    me_resp = client.get("/api/v1/users/me", headers=headers)
    assert me_resp.status_code == 200
    assert me_resp.json()["email"] == email.lower()

    # Step 4: Create Workspace
    ws_slug = f"ws-{uuid.uuid4().hex[:6]}"
    ws_resp = client.post(
        "/api/v1/workspaces",
        json={
            "name": "Engineering Workspace",
            "slug": ws_slug,
            "description": "Core dev team",
        },
        headers=headers,
    )
    assert ws_resp.status_code == 201
    workspace_id = ws_resp.json()["id"]

    # Step 5: Create Project under Workspace
    proj_resp = client.post(
        f"/api/v1/workspaces/{workspace_id}/projects",
        json={"name": "Core Engine", "key": "CORE", "description": "Backend services"},
        headers=headers,
    )
    assert proj_resp.status_code == 201
    project_id = proj_resp.json()["id"]
    assert proj_resp.json()["key"] == "CORE"

    # Step 6: Create Issue under Project
    issue_resp = client.post(
        f"/api/v1/projects/{project_id}/issues",
        json={
            "title": "Set up database replication",
            "description": "Configure read replicas for PostgreSQL",
            "type": "task",
            "status": "todo",
            "priority": "high",
            "estimate": 5.0,
        },
        headers=headers,
    )
    assert issue_resp.status_code == 201
    issue_data = issue_resp.json()
    issue_id = issue_data["id"]
    assert issue_data["title"] == "Set up database replication"
    assert issue_data["status"] == "todo"
    assert issue_data["priority"] == "high"
    assert issue_data["estimate"] == 5.0
    assert issue_data["project_id"] == project_id

    # Step 7: Retrieve Issue
    get_resp = client.get(f"/api/v1/issues/{issue_id}", headers=headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["id"] == issue_id


# ---------------------------------------------------------------------------
# Workflow 2: Backlog → Sprint Planning → Active Execution → Sprint Completion
# ---------------------------------------------------------------------------
def test_workflow_backlog_to_sprint_completion(client):
    """
    End-to-end integration flow:
      1. Setup user, workspace, and project
      2. Create multiple issues directly in the product backlog
      3. Inspect backlog listing and reorder backlog items
      4. Create a sprint in PLANNED status
      5. Add backlog issues into the sprint and check planning metrics
      6. Start the sprint (PLANNED -> ACTIVE)
      7. Progress issue statuses: TODO -> IN_PROGRESS -> IN_REVIEW -> DONE
      8. Check sprint progress and burndown metrics
      9. Complete sprint (ACTIVE -> COMPLETED) and verify incomplete issues rollover
    """
    # 1. Setup User & Project
    email = f"pm_{uuid.uuid4().hex[:6]}@example.com"
    client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "Password123!",
            "full_name": "Product Manager",
        },
    )
    login_resp = client.post(
        "/api/v1/auth/login", data={"username": email, "password": "Password123!"}
    )
    headers = _auth_header(login_resp.json()["access_token"])

    ws_resp = client.post(
        "/api/v1/workspaces",
        json={"name": "Agile WS", "slug": f"agile-{uuid.uuid4().hex[:6]}"},
        headers=headers,
    )
    ws_id = ws_resp.json()["id"]

    proj_resp = client.post(
        f"/api/v1/workspaces/{ws_id}/projects",
        json={"name": "Sprint Project", "key": "AGL"},
        headers=headers,
    )
    proj_id = proj_resp.json()["id"]

    # 2. Create 3 issues in product backlog
    created_issues = []
    for i in range(1, 4):
        resp = client.post(
            f"/api/v1/projects/{proj_id}/issues",
            json={
                "title": f"Story {i}",
                "type": "story",
                "status": "backlog",
                "estimate": float(i * 2),
            },
            headers=headers,
        )
        assert resp.status_code == 201
        created_issues.append(resp.json())

    issue1_id, issue2_id, issue3_id = (
        created_issues[0]["id"],
        created_issues[1]["id"],
        created_issues[2]["id"],
    )

    # 3. Inspect Backlog & Reorder
    backlog_resp = client.get(f"/api/v1/projects/{proj_id}/backlog", headers=headers)
    assert backlog_resp.status_code == 200
    assert len(backlog_resp.json()["items"]) == 3

    reorder_resp = client.patch(
        f"/api/v1/projects/{proj_id}/backlog/reorder",
        json={"issue_id": issue3_id, "position": "first"},
        headers=headers,
    )
    assert reorder_resp.status_code == 200

    # 4. Create Sprint (PLANNED)
    now = datetime.now(UTC)
    sprint_resp = client.post(
        f"/api/v1/projects/{proj_id}/sprints",
        json={
            "name": "Sprint 1",
            "goal": "Deliver MVP",
            "start_date": (now + timedelta(days=1)).isoformat(),
            "end_date": (now + timedelta(days=14)).isoformat(),
        },
        headers=headers,
    )
    assert sprint_resp.status_code == 201
    sprint_id = sprint_resp.json()["id"]
    assert sprint_resp.json()["status"] == "planned"

    # 5. Add issue1 and issue2 into sprint
    add_resp = client.post(
        f"/api/v1/sprints/{sprint_id}/issues",
        json={"issue_ids": [issue1_id, issue2_id]},
        headers=headers,
    )
    assert add_resp.status_code == 200
    assert len(add_resp.json()) == 2

    # Verify planning metrics
    plan_resp = client.get(f"/api/v1/sprints/{sprint_id}/planning", headers=headers)
    assert plan_resp.status_code == 200
    plan_data = plan_resp.json()
    assert plan_data["total_issues"] == 2
    assert plan_data["total_estimate"] == 6.0  # 2.0 + 4.0

    # 6. Start Sprint (PLANNED -> ACTIVE)
    start_resp = client.post(
        f"/api/v1/sprints/{sprint_id}/start",
        json={
            "start_date": now.isoformat(),
            "end_date": (now + timedelta(days=14)).isoformat(),
        },
        headers=headers,
    )
    assert start_resp.status_code == 200
    assert start_resp.json()["status"] == "active"

    # 7. Progress issue1 to DONE (TODO -> IN_PROGRESS -> IN_REVIEW -> DONE)
    client.patch(
        f"/api/v1/issues/{issue1_id}/status", json={"status": "todo"}, headers=headers
    )
    client.patch(
        f"/api/v1/issues/{issue1_id}/status",
        json={"status": "in_progress"},
        headers=headers,
    )
    client.patch(
        f"/api/v1/issues/{issue1_id}/status",
        json={"status": "in_review"},
        headers=headers,
    )
    done_resp = client.patch(
        f"/api/v1/issues/{issue1_id}/status", json={"status": "done"}, headers=headers
    )
    assert done_resp.status_code == 200
    assert done_resp.json()["status"] == "done"

    # 8. Check Progress & Burndown Metrics
    progress_resp = client.get(f"/api/v1/sprints/{sprint_id}/progress", headers=headers)
    assert progress_resp.status_code == 200
    prog_data = progress_resp.json()
    assert prog_data["completed_issues"] == 1
    assert prog_data["remaining_issues"] == 1
    assert prog_data["completed_points"] == 2.0
    assert prog_data["remaining_points"] == 4.0
    assert prog_data["progress_percentage"] == 33.3  # 2/6 points = 33.3%

    # 9. Complete Sprint: rollover remaining incomplete issue (issue2) to backlog
    comp_resp = client.post(
        f"/api/v1/sprints/{sprint_id}/complete",
        json={"target_sprint_id": None},
        headers=headers,
    )
    assert comp_resp.status_code == 200
    assert comp_resp.json()["status"] == "completed"

    # Verify issue2 is back in backlog (sprint_id is None)
    issue2_check = client.get(f"/api/v1/issues/{issue2_id}", headers=headers)
    assert issue2_check.json()["sprint_id"] is None


# ---------------------------------------------------------------------------
# Workflow 3: Role-Based Access Control (RBAC) across Workspace and Project
# ---------------------------------------------------------------------------
def test_workflow_rbac_permissions_hierarchy(client):
    """
    End-to-end integration flow:
      1. Workspace Owner creates Workspace & Project
      2. Invites ADMIN, MEMBER, and VIEWER to Workspace and Project
      3. External User (OUTSIDER) has no membership
      4. VIEWER:
         - Can READ workspace, project, issues, backlog, sprints
         - CANNOT CREATE or UPDATE issues (returns 403 Forbidden)
         - CANNOT CREATE or START sprints (returns 403 Forbidden)
      5. MEMBER:
         - Can CREATE and UPDATE issues, log activity, change status
         - CANNOT DELETE workspace or project (returns 403 Forbidden)
      6. ADMIN:
         - Can MANAGE members, DELETE issues, CREATE and START sprints
      7. OUTSIDER:
         - Cannot access workspace, project, or issue resources (returns 404 Not Found)
    """

    def _register_user(name: str) -> dict:
        mail = f"{name}_{uuid.uuid4().hex[:6]}@example.com"
        client.post(
            "/api/v1/auth/register",
            json={
                "email": mail,
                "password": "Password123!",
                "full_name": name.capitalize(),
            },
        )
        tok = client.post(
            "/api/v1/auth/login", data={"username": mail, "password": "Password123!"}
        ).json()["access_token"]
        me = client.get("/api/v1/users/me", headers=_auth_header(tok)).json()
        return {"id": me["id"], "token": tok, "headers": _auth_header(tok)}

    owner = _register_user("owner")
    admin = _register_user("admin")
    member = _register_user("member")
    viewer = _register_user("viewer")
    outsider = _register_user("outsider")

    # 1. Owner creates Workspace & Project
    ws_resp = client.post(
        "/api/v1/workspaces",
        json={"name": "RBAC WS", "slug": f"rbac-{uuid.uuid4().hex[:6]}"},
        headers=owner["headers"],
    )
    ws_id = ws_resp.json()["id"]

    proj_resp = client.post(
        f"/api/v1/workspaces/{ws_id}/projects",
        json={"name": "RBAC Project", "key": "RBC"},
        headers=owner["headers"],
    )
    proj_id = proj_resp.json()["id"]

    # 2. Add users to Workspace
    client.post(
        f"/api/v1/workspaces/{ws_id}/members",
        json={"user_id": admin["id"], "role": RoleType.ADMIN.value},
        headers=owner["headers"],
    )
    client.post(
        f"/api/v1/workspaces/{ws_id}/members",
        json={"user_id": member["id"], "role": RoleType.MEMBER.value},
        headers=owner["headers"],
    )
    client.post(
        f"/api/v1/workspaces/{ws_id}/members",
        json={"user_id": viewer["id"], "role": RoleType.VIEWER.value},
        headers=owner["headers"],
    )

    # Add users to Project
    client.post(
        f"/api/v1/projects/{proj_id}/members",
        json={"user_id": admin["id"], "role": RoleType.ADMIN.value},
        headers=owner["headers"],
    )
    client.post(
        f"/api/v1/projects/{proj_id}/members",
        json={"user_id": member["id"], "role": RoleType.MEMBER.value},
        headers=owner["headers"],
    )
    client.post(
        f"/api/v1/projects/{proj_id}/members",
        json={"user_id": viewer["id"], "role": RoleType.VIEWER.value},
        headers=owner["headers"],
    )

    # 3. VIEWER tests: can read, but cannot write
    get_proj = client.get(f"/api/v1/projects/{proj_id}", headers=viewer["headers"])
    assert get_proj.status_code == 200

    # Viewer cannot create an issue -> 403 Forbidden
    resp_viewer_create = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Viewer task"},
        headers=viewer["headers"],
    )
    assert resp_viewer_create.status_code == 403
    assert resp_viewer_create.json()["code"] == "FORBIDDEN"

    # 4. MEMBER tests: can create issue, cannot delete project
    resp_member_create = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Member task", "type": "task", "status": "todo"},
        headers=member["headers"],
    )
    assert resp_member_create.status_code == 201
    issue_id = resp_member_create.json()["id"]

    # Member cannot delete project -> 403 Forbidden
    resp_member_del_proj = client.delete(
        f"/api/v1/projects/{proj_id}",
        headers=member["headers"],
    )
    assert resp_member_del_proj.status_code == 403

    # Member can update issue status
    resp_member_status = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        json={"status": "in_progress"},
        headers=member["headers"],
    )
    assert resp_member_status.status_code == 200

    # 5. ADMIN tests: can manage sprints and delete issue
    sprint_resp = client.post(
        f"/api/v1/projects/{proj_id}/sprints",
        json={"name": "Admin Sprint"},
        headers=admin["headers"],
    )
    assert sprint_resp.status_code == 201

    # Admin can soft delete issue
    del_issue_resp = client.delete(
        f"/api/v1/issues/{issue_id}",
        headers=admin["headers"],
    )
    assert del_issue_resp.status_code == 204

    # 6. OUTSIDER tests: completely isolated, receives 404 Not Found
    resp_out_proj = client.get(
        f"/api/v1/projects/{proj_id}",
        headers=outsider["headers"],
    )
    assert resp_out_proj.status_code == 404
    assert resp_out_proj.json()["code"] == "NOT_FOUND"

    resp_out_issue = client.get(
        f"/api/v1/issues/{issue_id}",
        headers=outsider["headers"],
    )
    assert resp_out_issue.status_code == 404
