import uuid
from datetime import UTC, datetime
from typing import Annotated

import pytest
from fastapi import APIRouter, Depends, FastAPI
from fastapi.testclient import TestClient

from app.api.deps import (
    require_project_permission,
    require_project_role,
    require_workspace_permission,
    require_workspace_role,
)
from app.core.permissions import Permission
from app.core.security import create_access_token, hash_password
from app.db.session import get_db
from app.models.enums import RoleType
from app.models.membership import ProjectMember, WorkspaceMember
from app.models.project import Project
from app.models.user import User
from app.models.workspace import Workspace

# ---------------------------------------------------------------------------
# Test Router Setup
# ---------------------------------------------------------------------------
auth_test_router = APIRouter(prefix="/test")


@auth_test_router.get("/workspaces/{workspace_id}/viewer")
def get_ws_as_viewer(
    member: Annotated[
        WorkspaceMember, Depends(require_workspace_role(RoleType.VIEWER))
    ],
):
    return {"workspace_id": str(member.workspace_id), "role": member.role.value}


@auth_test_router.get("/workspaces/{workspace_id}/admin")
def get_ws_as_admin(
    member: Annotated[WorkspaceMember, Depends(require_workspace_role(RoleType.ADMIN))],
):
    return {"workspace_id": str(member.workspace_id), "role": member.role.value}


@auth_test_router.get("/workspaces/{workspace_id}/owner")
def get_ws_as_owner(
    member: Annotated[WorkspaceMember, Depends(require_workspace_role(RoleType.OWNER))],
):
    return {"workspace_id": str(member.workspace_id), "role": member.role.value}


@auth_test_router.delete("/workspaces/{workspace_id}")
def delete_ws(
    member: Annotated[
        WorkspaceMember,
        Depends(require_workspace_permission(Permission.WORKSPACE_DELETE)),
    ],
):
    return {"deleted": True, "workspace_id": str(member.workspace_id)}


@auth_test_router.get("/projects/{project_id}/member")
def get_project_as_member(
    member: Annotated[ProjectMember, Depends(require_project_role(RoleType.MEMBER))],
):
    return {"project_id": str(member.project_id), "role": member.role.value}


@auth_test_router.get("/projects/{project_id}/admin")
def get_project_as_admin(
    member: Annotated[ProjectMember, Depends(require_project_role(RoleType.ADMIN))],
):
    return {"project_id": str(member.project_id), "role": member.role.value}


@auth_test_router.post("/projects/{project_id}/issues")
def create_issue(
    member: Annotated[
        ProjectMember,
        Depends(require_project_permission(Permission.ISSUE_CREATE)),
    ],
):
    return {"created": True, "project_id": str(member.project_id)}


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
@pytest.fixture
def auth_test_app(db_session):
    test_app = FastAPI()
    test_app.dependency_overrides[get_db] = lambda: db_session
    test_app.include_router(auth_test_router)
    yield test_app
    test_app.dependency_overrides.clear()


@pytest.fixture
def client(auth_test_app):
    return TestClient(auth_test_app)


def _create_user(db_session, email: str) -> User:
    user = User(
        email=email,
        hashed_password=hash_password("Password123!"),
        full_name=email.split("@")[0],
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def _auth_header(user: User) -> dict[str, str]:
    token = create_access_token(subject=str(user.id))
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def setup_rbac_data(db_session):
    owner = _create_user(db_session, "owner@example.com")
    admin = _create_user(db_session, "admin@example.com")
    member = _create_user(db_session, "member@example.com")
    viewer = _create_user(db_session, "viewer@example.com")
    outsider = _create_user(db_session, "outsider@example.com")

    # Create workspace
    ws = Workspace(name="Acme Corp", slug="acme-corp", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.refresh(ws)

    # Add workspace memberships
    for u, r in [
        (owner, RoleType.OWNER),
        (admin, RoleType.ADMIN),
        (member, RoleType.MEMBER),
        (viewer, RoleType.VIEWER),
    ]:
        db_session.add(WorkspaceMember(workspace_id=ws.id, user_id=u.id, role=r))

    # Create project in workspace
    proj = Project(name="Project Apollo", key="APO", workspace_id=ws.id)
    db_session.add(proj)
    db_session.commit()
    db_session.refresh(proj)

    # Add project memberships for member and viewer
    db_session.add(
        ProjectMember(project_id=proj.id, user_id=member.id, role=RoleType.MEMBER)
    )
    db_session.add(
        ProjectMember(project_id=proj.id, user_id=viewer.id, role=RoleType.VIEWER)
    )
    db_session.commit()

    return {
        "owner": owner,
        "admin": admin,
        "member": member,
        "viewer": viewer,
        "outsider": outsider,
        "workspace": ws,
        "project": proj,
    }


# ---------------------------------------------------------------------------
# 1. Workspace Authorization Tests
# ---------------------------------------------------------------------------
def test_workspace_unauthenticated(client, setup_rbac_data):
    """Accessing protected workspace route without token fails with 401."""
    ws = setup_rbac_data["workspace"]
    resp = client.get(f"/test/workspaces/{ws.id}/viewer")
    assert resp.status_code == 401


def test_workspace_not_found(client, setup_rbac_data):
    """Non-existent workspace returns 404."""
    owner = setup_rbac_data["owner"]
    random_ws_id = uuid.uuid4()
    resp = client.get(
        f"/test/workspaces/{random_ws_id}/viewer",
        headers=_auth_header(owner),
    )
    assert resp.status_code == 404
    assert resp.json()["detail"] == "Workspace not found."


def test_workspace_soft_deleted(client, db_session, setup_rbac_data):
    """Soft-deleted workspace returns 404."""
    owner = setup_rbac_data["owner"]
    ws = setup_rbac_data["workspace"]
    ws.deleted_at = datetime.now(UTC)
    db_session.commit()

    resp = client.get(
        f"/test/workspaces/{ws.id}/viewer",
        headers=_auth_header(owner),
    )
    assert resp.status_code == 404


def test_workspace_outsider_gets_404(client, setup_rbac_data):
    """User outside workspace cannot access data or detect workspace existence (returns 404)."""
    outsider = setup_rbac_data["outsider"]
    ws = setup_rbac_data["workspace"]

    resp = client.get(
        f"/test/workspaces/{ws.id}/viewer",
        headers=_auth_header(outsider),
    )
    assert resp.status_code == 404
    assert resp.json()["detail"] == "Workspace not found."


def test_workspace_role_hierarchy_viewer(client, setup_rbac_data):
    """Viewer can access viewer route, but gets 403 on admin route."""
    viewer = setup_rbac_data["viewer"]
    ws = setup_rbac_data["workspace"]

    # Viewer route -> 200
    resp_viewer = client.get(
        f"/test/workspaces/{ws.id}/viewer",
        headers=_auth_header(viewer),
    )
    assert resp_viewer.status_code == 200
    assert resp_viewer.json()["role"] == "viewer"

    # Admin route -> 403
    resp_admin = client.get(
        f"/test/workspaces/{ws.id}/admin",
        headers=_auth_header(viewer),
    )
    assert resp_admin.status_code == 403
    assert resp_admin.json()["detail"] == "Insufficient permissions for this workspace."


def test_workspace_role_hierarchy_member(client, setup_rbac_data):
    """Member can access viewer route, but gets 403 on admin route."""
    member = setup_rbac_data["member"]
    ws = setup_rbac_data["workspace"]

    resp_viewer = client.get(
        f"/test/workspaces/{ws.id}/viewer",
        headers=_auth_header(member),
    )
    assert resp_viewer.status_code == 200

    resp_admin = client.get(
        f"/test/workspaces/{ws.id}/admin",
        headers=_auth_header(member),
    )
    assert resp_admin.status_code == 403


def test_workspace_role_hierarchy_admin(client, setup_rbac_data):
    """Admin can access viewer and admin routes, but gets 403 on owner route and delete perm."""
    admin = setup_rbac_data["admin"]
    ws = setup_rbac_data["workspace"]

    # Admin route -> 200
    resp_admin = client.get(
        f"/test/workspaces/{ws.id}/admin",
        headers=_auth_header(admin),
    )
    assert resp_admin.status_code == 200

    # Owner route -> 403
    resp_owner = client.get(
        f"/test/workspaces/{ws.id}/owner",
        headers=_auth_header(admin),
    )
    assert resp_owner.status_code == 403

    # Delete permission -> 403
    resp_del = client.delete(
        f"/test/workspaces/{ws.id}",
        headers=_auth_header(admin),
    )
    assert resp_del.status_code == 403


def test_workspace_owner_full_access(client, setup_rbac_data):
    """Owner has full access to viewer, admin, owner, and delete routes."""
    owner = setup_rbac_data["owner"]
    ws = setup_rbac_data["workspace"]

    resp_owner = client.get(
        f"/test/workspaces/{ws.id}/owner",
        headers=_auth_header(owner),
    )
    assert resp_owner.status_code == 200

    resp_del = client.delete(
        f"/test/workspaces/{ws.id}",
        headers=_auth_header(owner),
    )
    assert resp_del.status_code == 200
    assert resp_del.json()["deleted"] is True


# ---------------------------------------------------------------------------
# 2. Project Authorization Tests
# ---------------------------------------------------------------------------
def test_project_unauthenticated(client, setup_rbac_data):
    """Accessing project route without token returns 401."""
    proj = setup_rbac_data["project"]
    resp = client.get(f"/test/projects/{proj.id}/member")
    assert resp.status_code == 401


def test_project_not_found(client, setup_rbac_data):
    """Non-existent project returns 404."""
    owner = setup_rbac_data["owner"]
    random_proj_id = uuid.uuid4()
    resp = client.get(
        f"/test/projects/{random_proj_id}/member",
        headers=_auth_header(owner),
    )
    assert resp.status_code == 404
    assert resp.json()["detail"] == "Project not found."


def test_project_outsider_gets_404(client, setup_rbac_data):
    """User outside project and workspace gets 404."""
    outsider = setup_rbac_data["outsider"]
    proj = setup_rbac_data["project"]

    resp = client.get(
        f"/test/projects/{proj.id}/member",
        headers=_auth_header(outsider),
    )
    assert resp.status_code == 404
    assert resp.json()["detail"] == "Project not found."


def test_project_viewer_insufficient_role(client, setup_rbac_data):
    """Project viewer cannot access member route or create issues (403)."""
    viewer = setup_rbac_data["viewer"]
    proj = setup_rbac_data["project"]

    resp_member = client.get(
        f"/test/projects/{proj.id}/member",
        headers=_auth_header(viewer),
    )
    assert resp_member.status_code == 403
    assert resp_member.json()["detail"] == "Insufficient permissions for this project."

    resp_issue = client.post(
        f"/test/projects/{proj.id}/issues",
        headers=_auth_header(viewer),
    )
    assert resp_issue.status_code == 403


def test_project_member_can_create_issues(client, setup_rbac_data):
    """Project member can access member route and create issues, but not admin route."""
    member = setup_rbac_data["member"]
    proj = setup_rbac_data["project"]

    resp_member = client.get(
        f"/test/projects/{proj.id}/member",
        headers=_auth_header(member),
    )
    assert resp_member.status_code == 200

    resp_issue = client.post(
        f"/test/projects/{proj.id}/issues",
        headers=_auth_header(member),
    )
    assert resp_issue.status_code == 200
    assert resp_issue.json()["created"] is True

    resp_admin = client.get(
        f"/test/projects/{proj.id}/admin",
        headers=_auth_header(member),
    )
    assert resp_admin.status_code == 403


def test_workspace_admin_and_owner_inherit_project_admin(client, setup_rbac_data):
    """Workspace Admin and Owner inherit management access over projects in the workspace."""
    admin = setup_rbac_data["admin"]
    owner = setup_rbac_data["owner"]
    proj = setup_rbac_data["project"]

    # Admin inherits project admin access
    resp_admin = client.get(
        f"/test/projects/{proj.id}/admin",
        headers=_auth_header(admin),
    )
    assert resp_admin.status_code == 200

    # Owner inherits project admin access
    resp_owner = client.get(
        f"/test/projects/{proj.id}/admin",
        headers=_auth_header(owner),
    )
    assert resp_owner.status_code == 200
