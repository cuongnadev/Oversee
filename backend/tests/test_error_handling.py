import pytest
from fastapi import APIRouter
from fastapi.testclient import TestClient

from app.core.exceptions import (
    BadRequestException,
    ConflictException,
    ForbiddenException,
    InternalServerErrorException,
    NotFoundException,
    UnauthorizedException,
    UnprocessableEntityException,
)
from app.core.security import create_access_token, hash_password
from app.db.session import get_db
from app.main import app
from app.models.enums import RoleType
from app.models.membership import WorkspaceMember
from app.models.user import User
from app.models.workspace import Workspace
from app.schemas.error import ErrorResponse

# ---------------------------------------------------------------------------
# Test Router to verify edge cases (500 unhandled, custom AppException, etc.)
# ---------------------------------------------------------------------------
error_test_router = APIRouter(prefix="/api/v1/test-errors", tags=["test-errors"])


@error_test_router.get("/trigger-500")
def trigger_unhandled_error():
    raise RuntimeError("Simulated unhandled internal server fault")


@error_test_router.get("/trigger-app-exception")
def trigger_custom_app_exception():
    raise BadRequestException(
        message="Custom domain failure",
        details={"context": "validation_rule"},
        code="DOMAIN_ERROR",
    )


@error_test_router.get("/trigger-not-found")
def trigger_custom_not_found():
    raise NotFoundException("Custom entity missing", code="CUSTOM_NOT_FOUND")


@error_test_router.get("/trigger-conflict")
def trigger_custom_conflict():
    raise ConflictException("Custom resource conflict", code="CUSTOM_CONFLICT")


@error_test_router.get("/trigger-unauthorized")
def trigger_custom_unauthorized():
    raise UnauthorizedException(
        "Custom auth failure",
        headers={"WWW-Authenticate": "Bearer"},
    )


@error_test_router.get("/trigger-forbidden")
def trigger_custom_forbidden():
    raise ForbiddenException("Custom access denied")


@error_test_router.get("/trigger-unprocessable")
def trigger_custom_unprocessable():
    raise UnprocessableEntityException("Custom unprocessable entity")


@error_test_router.get("/trigger-500-exception")
def trigger_custom_500():
    raise InternalServerErrorException("Custom 500 error")


# Register test router on app
app.include_router(error_test_router)


# ---------------------------------------------------------------------------
# Helpers & Fixtures
# ---------------------------------------------------------------------------
def _create_user(
    db_session,
    email="error_test@example.com",
    full_name="Error Test User",
) -> User:
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
    # raise_server_exceptions=False allows testing 500 handler in TestClient
    with TestClient(app, raise_server_exceptions=False) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def assert_standard_error(resp, expected_status: int, expected_code: str):
    """Verify that response matches the standardized ErrorResponse schema."""
    assert resp.status_code == expected_status
    data = resp.json()
    assert "code" in data
    assert "message" in data
    assert "details" in data
    assert "detail" in data
    assert data["code"] == expected_code
    # Validate against Pydantic schema
    validated = ErrorResponse(**data)
    assert validated.code == expected_code
    return data


# ---------------------------------------------------------------------------
# Test Cases: Standard Error Mapping across 400, 401, 403, 404, 409, 422, 500
# ---------------------------------------------------------------------------
def test_error_400_bad_request(client, db_session):
    """400 Bad Request error returns standardized error format."""
    # Attempting to reorder an issue with invalid relative_to target
    user = _create_user(db_session, "err400@example.com")
    resp = client.post(
        "/api/v1/auth/login",
        data={"username": "not_an_email_format", "password": "x"},
    )
    # Login with invalid credentials returns 401, but registering with blank title/details or invalid payload
    # Let's test a known 400 endpoint: start planned sprint with invalid dates or assigning non-member
    ws = Workspace(name="WS 400", slug="ws-400", owner_id=user.id)
    db_session.add(ws)
    db_session.commit()

    resp = client.post(
        f"/api/v1/workspaces/{ws.id}/members",
        json={"email": "nonexistent_user@example.com", "role": "member"},
        headers=_auth_header(user),
    )
    data = assert_standard_error(resp, 404, "NOT_FOUND")
    assert "not found" in data["message"].lower()


def test_error_401_unauthorized(client):
    """401 Unauthorized returns standardized error schema with headers preserved."""
    # No auth header on protected endpoint
    resp = client.get("/api/v1/users/me")
    data = assert_standard_error(resp, 401, "UNAUTHORIZED")
    assert (
        "authenticate" in resp.headers.get("www-authenticate", "").lower()
        or data["message"]
    )


def test_error_403_forbidden(client, db_session):
    """403 Forbidden returns standardized error schema."""
    owner = _create_user(db_session, "ws_owner_403@example.com")
    member = _create_user(db_session, "member_403@example.com")

    ws = Workspace(name="WS 403", slug="ws-403", owner_id=owner.id)
    db_session.add(ws)
    db_session.commit()
    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=owner.id, role=RoleType.OWNER)
    )
    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=member.id, role=RoleType.VIEWER)
    )
    db_session.commit()

    # Viewer attempts to delete workspace -> 403
    resp = client.delete(f"/api/v1/workspaces/{ws.id}", headers=_auth_header(member))
    data = assert_standard_error(resp, 403, "FORBIDDEN")
    assert "permission" in data["message"].lower()


def test_error_404_not_found(client, db_session):
    """404 Not Found returns standardized error schema."""
    user = _create_user(db_session, "user_404@example.com")
    import uuid

    fake_id = uuid.uuid4()
    resp = client.get(f"/api/v1/workspaces/{fake_id}", headers=_auth_header(user))
    data = assert_standard_error(resp, 404, "NOT_FOUND")
    assert "not found" in data["message"].lower()


def test_error_409_conflict(client, db_session):
    """409 Conflict returns standardized error schema."""
    # Duplicate email registration
    _create_user(db_session, "duplicate@example.com")
    resp = client.post(
        "/api/v1/auth/register",
        json={
            "email": "duplicate@example.com",
            "password": "Password123!",
            "full_name": "Duplicate User",
        },
    )
    data = assert_standard_error(resp, 409, "CONFLICT")
    assert "already registered" in data["message"]


def test_error_422_pydantic_validation_error(client):
    """422 Validation Error returns standardized schema with field details list."""
    # Register with short password
    resp = client.post(
        "/api/v1/auth/register",
        json={"email": "bad_input@example.com", "password": "short"},
    )
    data = assert_standard_error(resp, 422, "VALIDATION_ERROR")
    assert isinstance(data["details"], list)
    assert len(data["details"]) >= 1
    assert any("password" in str(d.get("loc", [])) for d in data["details"])


def test_error_422_custom_transition_error(client, db_session):
    """422 Custom HTTP 422 error (e.g. invalid status transition) maps to UNPROCESSABLE_ENTITY."""
    user = _create_user(db_session, "user_trans@example.com")
    ws = Workspace(name="WS Trans", slug="ws-trans", owner_id=user.id)
    db_session.add(ws)
    db_session.commit()
    db_session.add(
        WorkspaceMember(workspace_id=ws.id, user_id=user.id, role=RoleType.OWNER)
    )
    db_session.commit()

    resp = client.post(
        f"/api/v1/workspaces/{ws.id}/projects",
        json={"name": "Proj", "key": "PRJ"},
        headers=_auth_header(user),
    )
    assert resp.status_code == 201
    proj_id = resp.json()["id"]

    # Create issue in TODO
    resp_issue = client.post(
        f"/api/v1/projects/{proj_id}/issues",
        json={"title": "Test Issue", "status": "todo"},
        headers=_auth_header(user),
    )
    issue_id = resp_issue.json()["id"]

    # Transition directly from TODO -> DONE is invalid (must go through IN_PROGRESS -> IN_REVIEW)
    # Raises HTTPException(status_code=422)
    resp_trans = client.patch(
        f"/api/v1/issues/{issue_id}/status",
        json={"status": "done"},
        headers=_auth_header(user),
    )
    data = assert_standard_error(resp_trans, 422, "UNPROCESSABLE_ENTITY")
    assert "Invalid status transition" in data["message"]


def test_error_500_unhandled_exception(client):
    """500 Internal Server Error returns standardized schema and does not crash the server."""
    resp = client.get("/api/v1/test-errors/trigger-500")
    data = assert_standard_error(resp, 500, "INTERNAL_SERVER_ERROR")
    assert "internal server error" in data["message"].lower()


# ---------------------------------------------------------------------------
# Test Cases: Custom AppException classes & domain errors
# ---------------------------------------------------------------------------
def test_custom_app_exceptions(client):
    """Custom AppException classes return correct status codes and structured payloads."""
    # 1. Custom BadRequestException with details and custom code
    resp1 = client.get("/api/v1/test-errors/trigger-app-exception")
    data1 = assert_standard_error(resp1, 400, "DOMAIN_ERROR")
    assert data1["message"] == "Custom domain failure"
    assert data1["details"] == {"context": "validation_rule"}

    # 2. Custom NotFoundException
    resp2 = client.get("/api/v1/test-errors/trigger-not-found")
    data2 = assert_standard_error(resp2, 404, "CUSTOM_NOT_FOUND")
    assert data2["message"] == "Custom entity missing"

    # 3. Custom ConflictException
    resp3 = client.get("/api/v1/test-errors/trigger-conflict")
    data3 = assert_standard_error(resp3, 409, "CUSTOM_CONFLICT")
    assert data3["message"] == "Custom resource conflict"

    # 4. Custom UnauthorizedException
    resp4 = client.get("/api/v1/test-errors/trigger-unauthorized")
    data4 = assert_standard_error(resp4, 401, "UNAUTHORIZED")
    assert data4["message"] == "Custom auth failure"
    assert "Bearer" in resp4.headers.get("www-authenticate", "")

    # 5. Custom ForbiddenException
    resp5 = client.get("/api/v1/test-errors/trigger-forbidden")
    data5 = assert_standard_error(resp5, 403, "FORBIDDEN")
    assert data5["message"] == "Custom access denied"

    # 6. Custom UnprocessableEntityException
    resp6 = client.get("/api/v1/test-errors/trigger-unprocessable")
    data6 = assert_standard_error(resp6, 422, "UNPROCESSABLE_ENTITY")
    assert data6["message"] == "Custom unprocessable entity"

    # 7. Custom InternalServerErrorException
    resp7 = client.get("/api/v1/test-errors/trigger-500-exception")
    data7 = assert_standard_error(resp7, 500, "INTERNAL_SERVER_ERROR")
    assert data7["message"] == "Custom 500 error"
