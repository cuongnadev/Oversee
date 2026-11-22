from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from app.db.session import get_db
from app.main import app


@pytest.fixture
def client(db_session):
    app.dependency_overrides[get_db] = lambda: db_session
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def _auth_headers(client: TestClient, email: str = "backlog_owner@example.com") -> dict[str, str]:
    password = "StrongPassword123!"
    client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "full_name": "Backlog Owner"},
    )
    login = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    token = login.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _create_workspace_and_project(client: TestClient, headers: dict[str, str]) -> str:
    ws = client.post(
        "/api/v1/workspaces",
        json={"name": "Backlog WS", "slug": "backlog-ws"},
        headers=headers,
    )
    assert ws.status_code == 201
    ws_id = ws.json()["id"]

    proj = client.post(
        f"/api/v1/workspaces/{ws_id}/projects",
        json={"name": "Platform", "key": "PLT"},
        headers=headers,
    )
    assert proj.status_code == 201
    return proj.json()["id"]


def test_issue_start_end_dates_and_grouped_backlog(client: TestClient) -> None:
    headers = _auth_headers(client)
    project_id = _create_workspace_and_project(client, headers)

    # Create active sprint and planned sprint
    now = datetime.now(UTC)
    active_sprint = client.post(
        f"/api/v1/projects/{project_id}/sprints",
        json={
            "name": "Sprint 3",
            "goal": "Release v2.0",
            "status": "active",
            "start_date": now.isoformat(),
            "end_date": (now + timedelta(days=14)).isoformat(),
        },
        headers=headers,
    )
    assert active_sprint.status_code == 201
    active_sprint_id = active_sprint.json()["id"]

    planned_sprint = client.post(
        f"/api/v1/projects/{project_id}/sprints",
        json={"name": "Sprint 4", "status": "planned"},
        headers=headers,
    )
    assert planned_sprint.status_code == 201

    # Create issues with start_date and end_date in active sprint (one done, one in_progress)
    issue1 = client.post(
        f"/api/v1/projects/{project_id}/issues",
        json={
            "title": "Done sprint task",
            "status": "done",
            "sprint_id": active_sprint_id,
            "estimate": 5,
            "start_date": now.isoformat(),
            "end_date": (now + timedelta(days=3)).isoformat(),
        },
        headers=headers,
    )
    assert issue1.status_code == 201
    assert issue1.json()["start_date"] is not None
    assert issue1.json()["end_date"] is not None

    issue2 = client.post(
        f"/api/v1/projects/{project_id}/issues",
        json={
            "title": "Active sprint task",
            "status": "in_progress",
            "sprint_id": active_sprint_id,
            "estimate": 3,
        },
        headers=headers,
    )
    assert issue2.status_code == 201
    issue2_id = issue2.json()["id"]

    # Update issue2 dates via PATCH
    patch_res = client.patch(
        f"/api/v1/issues/{issue2_id}",
        json={
            "start_date": (now + timedelta(days=1)).isoformat(),
            "end_date": (now + timedelta(days=5)).isoformat(),
        },
        headers=headers,
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["start_date"] is not None
    assert patch_res.json()["end_date"] is not None

    # Invalid date range rejected with 422
    bad_res = client.patch(
        f"/api/v1/issues/{issue2_id}",
        json={
            "start_date": (now + timedelta(days=10)).isoformat(),
            "end_date": (now + timedelta(days=2)).isoformat(),
        },
        headers=headers,
    )
    assert bad_res.status_code == 422

    # Create unassigned backlog issue
    backlog_issue = client.post(
        f"/api/v1/projects/{project_id}/issues",
        json={"title": "Unassigned backlog item", "estimate": 2},
        headers=headers,
    )
    assert backlog_issue.status_code == 201

    # Query new grouped backlog route
    grouped = client.get(
        f"/api/v1/projects/{project_id}/backlog/grouped",
        headers=headers,
    )
    assert grouped.status_code == 200
    body = grouped.json()
    assert body["total_issues"] == 3
    assert body["backlog_total_issues"] == 1
    assert body["backlog_story_points"] == 2.0
    assert len(body["sprints"]) == 2
    # Active sprint ordered first
    s0 = body["sprints"][0]
    assert s0["sprint"]["name"] == "Sprint 3"
    assert s0["total_issues"] == 2
    assert s0["completed_issues"] == 1
    assert s0["total_story_points"] == 8.0
    assert s0["completed_story_points"] == 5.0
    assert s0["completion_percentage"] == 50.0
