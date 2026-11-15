import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy import select

from app.core.security import verify_password
from app.db.session import get_db
from app.main import app
from app.models.user import User
from app.schemas.auth import RegisterRequest
from app.services.auth import register_user


# ---------------------------------------------------------------------------
# 1. Pydantic Schema Validation Tests
# ---------------------------------------------------------------------------
def test_register_request_valid():
    """Verify that a valid payload parses successfully and normalizes email."""
    req = RegisterRequest(
        email="  TestUser@Example.COM  ",
        full_name="  John Doe  ",
        password="SecurePassword123",
    )
    assert req.email == "testuser@example.com"
    assert req.full_name == "John Doe"
    assert req.password == "SecurePassword123"


def test_register_request_invalid_email():
    """Verify that invalid emails raise ValidationError."""
    with pytest.raises(ValidationError):
        RegisterRequest(
            email="not-an-email",
            full_name="Valid Name",
            password="SecurePassword123",
        )


def test_register_request_blank_full_name():
    """Verify that blank or empty full_name raises ValidationError."""
    with pytest.raises(ValidationError):
        RegisterRequest(
            email="user@example.com",
            full_name="   ",
            password="SecurePassword123",
        )


@pytest.mark.parametrize(
    "invalid_password,expected_error",
    [
        ("Short1!", "at least 8 characters"),
        ("nouppercase123", "at least one uppercase letter"),
        ("NOLOWERCASE123", "at least one lowercase letter"),
        ("NoDigitsInPassword", "at least one digit"),
        ("A" * 129 + "a1", "128 characters"),
    ],
)
def test_register_request_password_strength_validation(
    invalid_password, expected_error
):
    """Verify password strength validation rules."""
    with pytest.raises(ValidationError) as exc:
        RegisterRequest(
            email="user@example.com",
            full_name="Valid Name",
            password=invalid_password,
        )
    assert expected_error in str(exc.value)


# ---------------------------------------------------------------------------
# 2. Service Layer Tests
# ---------------------------------------------------------------------------
def test_register_user_service_success(db_session):
    """Verify that register_user creates a user with hashed password."""
    req = RegisterRequest(
        email="service_user@example.com",
        full_name="Service User",
        password="ValidPassword123",
    )
    user = register_user(db_session, req)

    assert user.id is not None
    assert user.email == "service_user@example.com"
    assert user.full_name == "Service User"
    assert user.is_active is True
    # Password must be hashed with bcrypt, NEVER raw
    assert user.hashed_password != "ValidPassword123"
    assert user.hashed_password.startswith("$2b$")
    assert verify_password("ValidPassword123", user.hashed_password) is True


def test_register_user_service_duplicate_email_conflict(db_session):
    """Verify that register_user raises HTTP 409 when email already exists."""
    req1 = RegisterRequest(
        email="conflict@example.com",
        full_name="First User",
        password="ValidPassword123",
    )
    register_user(db_session, req1)

    req2 = RegisterRequest(
        email="CONFLICT@example.com",  # Case insensitive duplicate
        full_name="Second User",
        password="ValidPassword123",
    )
    with pytest.raises(HTTPException) as exc:
        register_user(db_session, req2)

    assert exc.value.status_code == 409
    assert exc.value.detail == "Email is already registered."


# ---------------------------------------------------------------------------
# 3. HTTP API Endpoint Integration Tests
# ---------------------------------------------------------------------------
def test_api_register_success(db_session):
    """Test POST /api/v1/auth/register creates user and does not leak password."""
    app.dependency_overrides[get_db] = lambda: db_session
    client = TestClient(app)

    payload = {
        "email": "newuser@example.com",
        "full_name": "New User",
        "password": "StrongPassword999",
    }
    response = client.post("/api/v1/auth/register", json=payload)
    app.dependency_overrides.clear()

    assert response.status_code == 201
    data = response.json()

    assert "id" in data
    assert data["email"] == "newuser@example.com"
    assert data["full_name"] == "New User"
    assert data["is_active"] is True
    assert "created_at" in data
    assert "updated_at" in data

    # MUST NOT leak password or hashed_password
    assert "password" not in data
    assert "hashed_password" not in data

    # Verify directly in database that password was hashed
    stored_user = db_session.scalar(
        select(User).where(User.email == "newuser@example.com")
    )
    assert stored_user is not None
    assert stored_user.hashed_password.startswith("$2b$")
    assert verify_password("StrongPassword999", stored_user.hashed_password) is True


def test_api_register_duplicate_email_returns_409(db_session):
    """Test POST /api/v1/auth/register returns 409 Conflict on existing email."""
    app.dependency_overrides[get_db] = lambda: db_session
    client = TestClient(app)

    payload = {
        "email": "duplicate@example.com",
        "full_name": "Existing User",
        "password": "Password12345",
    }
    # First registration
    resp1 = client.post("/api/v1/auth/register", json=payload)
    assert resp1.status_code == 201

    # Second registration with same email
    resp2 = client.post("/api/v1/auth/register", json=payload)
    app.dependency_overrides.clear()

    assert resp2.status_code == 409
    assert resp2.json()["detail"] == "Email is already registered."


def test_api_register_invalid_password_returns_422(db_session):
    """Test POST /api/v1/auth/register returns 422 Unprocessable Entity for weak password."""
    app.dependency_overrides[get_db] = lambda: db_session
    client = TestClient(app)

    payload = {
        "email": "weak@example.com",
        "full_name": "Weak Password User",
        "password": "weak",  # too short, no uppercase, no numbers
    }
    response = client.post("/api/v1/auth/register", json=payload)
    app.dependency_overrides.clear()

    assert response.status_code == 422
    assert "password" in str(response.json())
