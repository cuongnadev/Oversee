from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.core.security import (
    TOKEN_TYPE_ACCESS,
    TOKEN_TYPE_REFRESH,
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
)
from app.db.session import get_db
from app.main import app
from app.models.user import User


def _create_test_user(
    db_session,
    email="login_user@example.com",
    password="SecurePassword123",
    is_active=True,
    deleted_at=None,
):
    user = User(
        email=email.lower().strip(),
        hashed_password=hash_password(password),
        full_name="Login Test User",
        is_active=is_active,
        deleted_at=deleted_at,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


# ---------------------------------------------------------------------------
# 1. Login Tests
# ---------------------------------------------------------------------------
def test_login_success(db_session):
    """Test POST /api/v1/auth/login succeeds with correct credentials."""
    user = _create_test_user(
        db_session, email="success@example.com", password="Password123!"
    )

    app.dependency_overrides[get_db] = lambda: db_session
    client = TestClient(app)

    response = client.post(
        "/api/v1/auth/login",
        json={"email": "success@example.com", "password": "Password123!"},
    )
    app.dependency_overrides.clear()

    assert response.status_code == 200
    data = response.json()

    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"

    # Verify access token
    access_payload = decode_token(data["access_token"], expected_type=TOKEN_TYPE_ACCESS)
    assert access_payload["sub"] == str(user.id)

    # Verify refresh token
    refresh_payload = decode_token(
        data["refresh_token"], expected_type=TOKEN_TYPE_REFRESH
    )
    assert refresh_payload["sub"] == str(user.id)


def test_login_case_insensitive_email(db_session):
    """Test login succeeds regardless of email casing."""
    user = _create_test_user(
        db_session, email="casing@example.com", password="Password123!"
    )

    app.dependency_overrides[get_db] = lambda: db_session
    client = TestClient(app)

    response = client.post(
        "/api/v1/auth/login",
        json={"email": "CASING@EXAMPLE.COM", "password": "Password123!"},
    )
    app.dependency_overrides.clear()

    assert response.status_code == 200
    assert decode_token(response.json()["access_token"])["sub"] == str(user.id)


def test_login_incorrect_password_returns_401(db_session):
    """Test login fails with generic 401 when password is wrong."""
    _create_test_user(
        db_session, email="wrong_pwd@example.com", password="CorrectPassword123!"
    )

    app.dependency_overrides[get_db] = lambda: db_session
    client = TestClient(app)

    response = client.post(
        "/api/v1/auth/login",
        json={"email": "wrong_pwd@example.com", "password": "WrongPassword999!"},
    )
    app.dependency_overrides.clear()

    assert response.status_code == 401
    assert response.json()["detail"] == "Incorrect email or password."
    assert response.headers["WWW-Authenticate"] == "Bearer"


def test_login_nonexistent_user_returns_401(db_session):
    """Test login fails with identical generic 401 when user does not exist."""
    app.dependency_overrides[get_db] = lambda: db_session
    client = TestClient(app)

    response = client.post(
        "/api/v1/auth/login",
        json={"email": "nobody@example.com", "password": "AnyPassword123!"},
    )
    app.dependency_overrides.clear()

    assert response.status_code == 401
    assert response.json()["detail"] == "Incorrect email or password."


def test_login_inactive_user_returns_401(db_session):
    """Test login fails when user is inactive."""
    _create_test_user(
        db_session,
        email="inactive@example.com",
        password="Password123!",
        is_active=False,
    )

    app.dependency_overrides[get_db] = lambda: db_session
    client = TestClient(app)

    response = client.post(
        "/api/v1/auth/login",
        json={"email": "inactive@example.com", "password": "Password123!"},
    )
    app.dependency_overrides.clear()

    assert response.status_code == 401
    assert response.json()["detail"] == "Incorrect email or password."


def test_login_soft_deleted_user_returns_401(db_session):
    """Test login fails when user is soft-deleted."""
    _create_test_user(
        db_session,
        email="deleted@example.com",
        password="Password123!",
        deleted_at=datetime.now(UTC),
    )

    app.dependency_overrides[get_db] = lambda: db_session
    client = TestClient(app)

    response = client.post(
        "/api/v1/auth/login",
        json={"email": "deleted@example.com", "password": "Password123!"},
    )
    app.dependency_overrides.clear()

    assert response.status_code == 401
    assert response.json()["detail"] == "Incorrect email or password."


# ---------------------------------------------------------------------------
# 2. Refresh Token Rotation Tests
# ---------------------------------------------------------------------------
def test_refresh_token_rotation_success():
    """Test POST /api/v1/auth/refresh rotates token and revokes old token."""
    client = TestClient(app)
    user_id = "test-user-rotate"
    refresh_token = create_refresh_token(subject=user_id)

    response = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": refresh_token}
    )
    assert response.status_code == 200
    data = response.json()

    assert "access_token" in data
    assert "refresh_token" in data
    new_refresh = data["refresh_token"]
    assert new_refresh != refresh_token

    # Verify newly minted access and refresh tokens
    assert (
        decode_token(data["access_token"], expected_type=TOKEN_TYPE_ACCESS)["sub"]
        == user_id
    )
    assert decode_token(new_refresh, expected_type=TOKEN_TYPE_REFRESH)["sub"] == user_id

    # Crucial security test: The old refresh token MUST be rejected on replay
    replay_response = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": refresh_token}
    )
    assert replay_response.status_code == 401
    assert "revoked" in replay_response.json()["detail"].lower()


def test_refresh_fails_on_expired_token():
    """Test POST /api/v1/auth/refresh rejects expired token."""
    client = TestClient(app)
    expired_token = create_refresh_token(
        subject="user-exp", expires_delta=timedelta(seconds=-1)
    )

    response = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": expired_token}
    )
    assert response.status_code == 401
    assert "expired" in response.json()["detail"].lower()


def test_refresh_fails_on_access_token():
    """Test POST /api/v1/auth/refresh rejects access token."""
    client = TestClient(app)
    access_token = create_access_token(subject="user-wrong")

    response = client.post("/api/v1/auth/refresh", json={"refresh_token": access_token})
    assert response.status_code == 401
    assert "expected token type 'refresh'" in response.json()["detail"].lower()


# ---------------------------------------------------------------------------
# 3. Logout Tests
# ---------------------------------------------------------------------------
def test_logout_revokes_refresh_token():
    """Test POST /api/v1/auth/logout revokes refresh token so it cannot be used again."""
    client = TestClient(app)
    user_id = "test-user-logout"
    refresh_token = create_refresh_token(subject=user_id)

    # Logout
    response = client.post("/api/v1/auth/logout", json={"refresh_token": refresh_token})
    assert response.status_code == 200
    assert response.json() == {"message": "Successfully logged out."}

    # Attempting to use the revoked token at /refresh MUST be rejected
    refresh_resp = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": refresh_token}
    )
    assert refresh_resp.status_code == 401
    assert "revoked" in refresh_resp.json()["detail"].lower()


def test_logout_malformed_token_returns_401():
    """Test POST /api/v1/auth/logout returns 401 on malformed token."""
    client = TestClient(app)
    response = client.post(
        "/api/v1/auth/logout", json={"refresh_token": "malformed.jwt.token"}
    )
    assert response.status_code == 401
    assert "invalid token" in response.json()["detail"].lower()
