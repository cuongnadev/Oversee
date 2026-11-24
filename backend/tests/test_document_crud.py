from datetime import UTC, datetime, timedelta

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


def _create_user(db_session, email: str, full_name: str) -> User:
    user = User(
        email=email.lower().strip(),
        hashed_password=hash_password("Password123!"),
        full_name=full_name,
        is_active=True,
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
def setup_doc_data(db_session):
    owner = _create_user(db_session, "doc_owner@example.com", "Owner")
    admin = _create_user(db_session, "doc_admin@example.com", "Admin")
    member = _create_user(db_session, "doc_member@example.com", "Member")
    viewer = _create_user(db_session, "doc_viewer@example.com", "Viewer")
    outsider = _create_user(db_session, "doc_outsider@example.com", "Outsider")

    ws = Workspace(name="Doc Workspace", slug="doc-ws", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.refresh(ws)

    for u, r in [
        (owner, RoleType.OWNER),
        (admin, RoleType.ADMIN),
        (member, RoleType.MEMBER),
        (viewer, RoleType.VIEWER),
    ]:
        db_session.add(WorkspaceMember(workspace_id=ws.id, user_id=u.id, role=r))
    db_session.commit()

    project = Project(workspace_id=ws.id, name="Doc Project", key="DOC")
    db_session.add(project)
    db_session.commit()
    db_session.refresh(project)

    for u, r in [
        (admin, RoleType.ADMIN),
        (member, RoleType.MEMBER),
        (viewer, RoleType.VIEWER),
    ]:
        db_session.add(ProjectMember(project_id=project.id, user_id=u.id, role=r))
    db_session.commit()

    return {
        "owner": owner,
        "admin": admin,
        "member": member,
        "viewer": viewer,
        "outsider": outsider,
        "project": project,
    }


def test_create_document_via_project_and_top_level_routes(client, setup_doc_data):
    proj_id = setup_doc_data["project"].id
    member = setup_doc_data["member"]

    resp1 = client.post(
        f"/api/v1/projects/{proj_id}/documents",
        json={"title": "  Architecture RFC  ", "content": "# Overview\nDetails"},
        headers=_auth_header(member),
    )
    assert resp1.status_code == 201
    doc1 = resp1.json()
    assert doc1["title"] == "Architecture RFC"
    assert doc1["content"] == "# Overview\nDetails"
    assert doc1["project_id"] == str(proj_id)
    assert doc1["author_id"] == str(member.id)
    assert doc1["deleted_at"] is None

    resp2 = client.post(
        "/api/v1/documents",
        json={"project_id": str(proj_id), "title": "API Runbook", "content": None},
        headers=_auth_header(member),
    )
    assert resp2.status_code == 201
    assert resp2.json()["title"] == "API Runbook"


def test_create_document_validation_and_permissions(client, setup_doc_data):
    proj_id = setup_doc_data["project"].id

    # Blank title rejected
    resp_blank = client.post(
        f"/api/v1/projects/{proj_id}/documents",
        json={"title": "   ", "content": "text"},
        headers=_auth_header(setup_doc_data["member"]),
    )
    assert resp_blank.status_code == 422

    # Missing project_id on top-level route rejected
    resp_no_proj = client.post(
        "/api/v1/documents",
        json={"title": "Orphan Doc"},
        headers=_auth_header(setup_doc_data["member"]),
    )
    assert resp_no_proj.status_code == 422

    # Viewer forbidden
    resp_viewer = client.post(
        f"/api/v1/projects/{proj_id}/documents",
        json={"title": "Viewer Doc"},
        headers=_auth_header(setup_doc_data["viewer"]),
    )
    assert resp_viewer.status_code == 403

    # Outsider gets 404
    resp_outsider = client.post(
        f"/api/v1/projects/{proj_id}/documents",
        json={"title": "Outsider Doc"},
        headers=_auth_header(setup_doc_data["outsider"]),
    )
    assert resp_outsider.status_code == 404


def test_document_list_get_update_delete_flow(client, setup_doc_data):
    proj_id = setup_doc_data["project"].id
    member_h = _auth_header(setup_doc_data["member"])
    admin_h = _auth_header(setup_doc_data["admin"])
    viewer_h = _auth_header(setup_doc_data["viewer"])

    d1 = client.post(
        f"/api/v1/projects/{proj_id}/documents",
        json={"title": "First Doc", "content": "v1"},
        headers=member_h,
    ).json()
    d2 = client.post(
        f"/api/v1/projects/{proj_id}/documents",
        json={"title": "Second Doc", "content": "v1"},
        headers=member_h,
    ).json()

    # Viewer can list and read
    list_resp = client.get(f"/api/v1/projects/{proj_id}/documents", headers=viewer_h)
    assert list_resp.status_code == 200
    assert {d["id"] for d in list_resp.json()} == {d1["id"], d2["id"]}

    get_resp = client.get(f"/api/v1/documents/{d1['id']}", headers=viewer_h)
    assert get_resp.status_code == 200
    assert get_resp.json()["title"] == "First Doc"

    # Member can update
    patch_resp = client.patch(
        f"/api/v1/documents/{d1['id']}",
        json={"title": "First Doc Updated", "content": "v2"},
        headers=member_h,
    )
    assert patch_resp.status_code == 200
    assert patch_resp.json()["title"] == "First Doc Updated"
    assert patch_resp.json()["content"] == "v2"

    # Member cannot delete, Admin can delete
    del_member = client.delete(f"/api/v1/documents/{d1['id']}", headers=member_h)
    assert del_member.status_code == 403

    del_admin = client.delete(f"/api/v1/documents/{d1['id']}", headers=admin_h)
    assert del_admin.status_code == 204

    # Soft-deleted doc returns 404 and excluded from list
    assert (
        client.get(f"/api/v1/documents/{d1['id']}", headers=admin_h).status_code == 404
    )
    list_after = client.get(f"/api/v1/projects/{proj_id}/documents", headers=viewer_h)
    assert [d["id"] for d in list_after.json()] == [d2["id"]]


def test_quick_create_routes_issue_epic_sprint_document(client, setup_doc_data):
    """Validate backend supports creation of Issue, Epic, Sprint, and Document."""
    proj_id = setup_doc_data["project"].id
    headers = _auth_header(setup_doc_data["member"])

    # 1. Issue (task)
    issue_resp = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Implement auth flow", "type": "task", "priority": "high"},
        headers=headers,
    )
    assert issue_resp.status_code == 201
    assert issue_resp.json()["type"] == "task"

    # 2. Epic (Issue with type=epic)
    epic_resp = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Q4 Platform Revamp", "type": "epic", "priority": "medium"},
        headers=headers,
    )
    assert epic_resp.status_code == 201
    assert epic_resp.json()["type"] == "epic"

    # 3. Sprint
    start = datetime.now(UTC) + timedelta(days=1)
    end = start + timedelta(days=14)
    sprint_resp = client.post(
        f"/api/v1/projects/{proj_id}/sprints",
        json={
            "name": "Sprint 4",
            "goal": "Ship quick create",
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
        },
        headers=headers,
    )
    assert sprint_resp.status_code == 201
    assert sprint_resp.json()["name"] == "Sprint 4"

    # 4. Document
    doc_resp = client.post(
        f"/api/v1/projects/{proj_id}/documents",
        json={"title": "Release Notes", "content": "## Sprint 4"},
        headers=headers,
    )
    assert doc_resp.status_code == 201
    assert doc_resp.json()["title"] == "Release Notes"
