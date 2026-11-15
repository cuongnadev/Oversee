import uuid
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    revoke_token,
)
from app.db.session import get_db
from app.main import app
from app.models.user import User


def _create_test_user(
    db_session,
    email="me_test@example.com",
    full_name="Current User Test",
    avatar_url="https://example.com/avatar.png",
    password="SecurePassword123",
    is_active=True,
    deleted_at=None,
):
    user = User(
        email=email.lower().strip(),
        hashed_password=hash_password(password),
        full_name=full_name,
        avatar_url=avatar_url,
        is_active=is_active,
        deleted_at=deleted_at,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


@pytest.fixture
def client(db_session):
    """Provides a TestClient with get_db overridden to use db_session."""
    app.dependency_overrides[get_db] = lambda: db_session
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# 1. GET /api/v1/users/me Tests
# ---------------------------------------------------------------------------
def test_get_current_user_success(client, db_session):
    """Test GET /api/v1/users/me returns the authenticated user's profile."""
    user = _create_test_user(db_session)
    token = create_access_token(subject=str(user.id))

    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["id"] == str(user.id)
    assert data["email"] == user.email
    assert data["full_name"] == user.full_name
    assert data["avatar_url"] == user.avatar_url
    assert data["is_active"] is True
    assert "password" not in data
    assert "hashed_password" not in data


def test_get_current_user_unauthorized_no_token(client):
    """Test GET /api/v1/users/me without Authorization header fails with 401."""
    response = client.get("/api/v1/users/me")
    assert response.status_code == 401
    assert "WWW-Authenticate" in response.headers


def test_get_current_user_invalid_token(client):
    """Test GET /api/v1/users/me with malformed token fails with 401."""
    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": "Bearer not-a-valid-jwt-token"},
    )
    assert response.status_code == 401


def test_get_current_user_expired_token(client, db_session):
    """Test GET /api/v1/users/me with expired token fails with 401."""
    user = _create_test_user(db_session, email="expired@example.com")
    token = create_access_token(
        subject=str(user.id),
        expires_delta=-timedelta(minutes=1),
    )

    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Token has expired."


def test_get_current_user_revoked_token(client, db_session):
    """Test GET /api/v1/users/me with revoked token fails with 401."""
    user = _create_test_user(db_session, email="revoked@example.com")
    token = create_access_token(subject=str(user.id))
    revoke_token(token)

    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 401


def test_get_current_user_wrong_token_type(client, db_session):
    """Test GET /api/v1/users/me fails with 401 when a refresh token is supplied."""
    user = _create_test_user(db_session, email="refresh_user@example.com")
    refresh_token = create_refresh_token(subject=str(user.id))

    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {refresh_token}"},
    )
    assert response.status_code == 401


def test_get_current_user_nonexistent_user(client):
    """Test GET /api/v1/users/me fails with 401 when subject user does not exist."""
    random_id = str(uuid.uuid4())
    token = create_access_token(subject=random_id)

    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 401


def test_get_current_user_inactive_user(client, db_session):
    """Test GET /api/v1/users/me fails with 401 when user is inactive."""
    user = _create_test_user(
        db_session,
        email="inactive@example.com",
        is_active=False,
    )
    token = create_access_token(subject=str(user.id))

    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Inactive user."


def test_get_current_user_soft_deleted(client, db_session):
    """Test GET /api/v1/users/me fails with 401 when user is soft deleted."""
    user = _create_test_user(
        db_session,
        email="deleted@example.com",
        deleted_at=datetime.now(UTC),
    )
    token = create_access_token(subject=str(user.id))

    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 401


# ---------------------------------------------------------------------------
# 2. PATCH /api/v1/users/me Tests
# ---------------------------------------------------------------------------
def test_patch_current_user_update_full_name(client, db_session):
    """Test PATCH /api/v1/users/me updates full_name and persists change."""
    user = _create_test_user(db_session, email="patch1@example.com")
    token = create_access_token(subject=str(user.id))

    response = client.patch(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"full_name": "Updated Name"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["full_name"] == "Updated Name"
    assert data["email"] == user.email

    db_session.refresh(user)
    assert user.full_name == "Updated Name"


def test_patch_current_user_update_avatar_url(client, db_session):
    """Test PATCH /api/v1/users/me updates avatar_url."""
    user = _create_test_user(db_session, email="patch2@example.com")
    token = create_access_token(subject=str(user.id))

    response = client.patch(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"avatar_url": "https://cdn.example.com/new-avatar.png"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["avatar_url"] == "https://cdn.example.com/new-avatar.png"

    db_session.refresh(user)
    assert user.avatar_url == "https://cdn.example.com/new-avatar.png"


def test_patch_current_user_clear_avatar_url(client, db_session):
    """Test PATCH /api/v1/users/me allows setting avatar_url to null."""
    user = _create_test_user(
        db_session,
        email="patch3@example.com",
        avatar_url="https://example.com/avatar.png",
    )
    token = create_access_token(subject=str(user.id))

    response = client.patch(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"avatar_url": None},
    )

    assert response.status_code == 200
    assert response.json()["avatar_url"] is None

    db_session.refresh(user)
    assert user.avatar_url is None


def test_patch_current_user_blank_name_fails(client, db_session):
    """Test PATCH /api/v1/users/me rejects empty or whitespace-only full_name with 422."""
    user = _create_test_user(db_session, email="patch4@example.com")
    token = create_access_token(subject=str(user.id))

    response = client.patch(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"full_name": "   "},
    )

    assert response.status_code == 422


def test_patch_current_user_extra_fields_forbidden(client, db_session):
    """Test PATCH /api/v1/users/me rejects unexpected fields like email with 422."""
    user = _create_test_user(db_session, email="patch5@example.com")
    token = create_access_token(subject=str(user.id))

    response = client.patch(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"email": "new_email@example.com"},
    )

    assert response.status_code == 422


def test_patch_current_user_unauthorized(client):
    """Test PATCH /api/v1/users/me without token fails with 401."""
    response = client.patch(
        "/api/v1/users/me",
        json={"full_name": "Hacker"},
    )
    assert response.status_code == 401
