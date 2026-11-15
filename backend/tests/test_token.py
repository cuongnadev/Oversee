import uuid
from datetime import UTC, datetime, timedelta

import jwt
import pytest

from app.core.config import settings
from app.core.security import (
    TOKEN_TYPE_ACCESS,
    TOKEN_TYPE_REFRESH,
    TokenExpiredError,
    TokenInvalidError,
    create_access_token,
    create_refresh_token,
    decode_token,
    rotate_refresh_token,
)
from app.schemas.token import RefreshTokenRequest, Token, TokenPayload


def test_create_and_decode_access_token():
    """Verify access token creation and decoding."""
    user_id = uuid.uuid4()
    token = create_access_token(subject=user_id)

    payload = decode_token(token, expected_type=TOKEN_TYPE_ACCESS)
    assert payload["sub"] == str(user_id)
    assert payload["type"] == TOKEN_TYPE_ACCESS
    assert "exp" in payload
    assert "iat" in payload
    assert "jti" in payload
    # jti should be a valid UUID
    uuid.UUID(payload["jti"])


def test_create_and_decode_refresh_token():
    """Verify refresh token creation and decoding."""
    user_id = str(uuid.uuid4())
    token = create_refresh_token(subject=user_id)

    payload = decode_token(token, expected_type=TOKEN_TYPE_REFRESH)
    assert payload["sub"] == user_id
    assert payload["type"] == TOKEN_TYPE_REFRESH
    assert "exp" in payload
    assert "iat" in payload
    assert "jti" in payload


def test_access_token_default_expiry_matches_settings():
    """Verify access token expiration reflects settings.access_token_expire_minutes."""
    user_id = "test-user-123"
    token = create_access_token(subject=user_id)
    payload = decode_token(token)

    expected_duration = settings.access_token_expire_minutes * 60
    actual_duration = payload["exp"] - payload["iat"]
    assert actual_duration == expected_duration


def test_refresh_token_default_expiry_matches_settings():
    """Verify refresh token expiration reflects settings.refresh_token_expire_days."""
    user_id = "test-user-456"
    token = create_refresh_token(subject=user_id)
    payload = decode_token(token)

    expected_duration = settings.refresh_token_expire_days * 24 * 3600
    actual_duration = payload["exp"] - payload["iat"]
    assert actual_duration == expected_duration


def test_custom_token_expiry():
    """Verify custom expires_delta overrides settings default."""
    custom_delta = timedelta(minutes=42)
    token = create_access_token(subject="user-custom", expires_delta=custom_delta)
    payload = decode_token(token)

    assert payload["exp"] - payload["iat"] == 42 * 60


def test_extra_claims_included():
    """Verify extra claims are stored without overriding standard claims."""
    extra = {"email": "test@example.com", "role": "admin", "type": "ignored_override"}
    token = create_access_token(subject="user-extra", extra_claims=extra)
    payload = decode_token(token)

    assert payload["email"] == "test@example.com"
    assert payload["role"] == "admin"
    # type must remain 'access', not the overwritten value
    assert payload["type"] == TOKEN_TYPE_ACCESS


def test_expired_token_rejected():
    """Verify that an expired token raises TokenExpiredError."""
    past_delta = timedelta(seconds=-1)
    token = create_access_token(subject="user-expired", expires_delta=past_delta)

    with pytest.raises(TokenExpiredError, match="Token has expired"):
        decode_token(token)


def test_invalid_signature_rejected():
    """Verify that a token signed with a different key is rejected."""
    wrong_key = "different-secret-key-at-least-32-chars-long"
    payload = {
        "sub": "user-invalid",
        "type": TOKEN_TYPE_ACCESS,
        "exp": int((datetime.now(UTC) + timedelta(minutes=15)).timestamp()),
    }
    tampered_token = jwt.encode(payload, wrong_key, algorithm=settings.jwt_algorithm)

    with pytest.raises(TokenInvalidError, match="Invalid token"):
        decode_token(tampered_token)


def test_malformed_token_rejected():
    """Verify that malformed token strings raise TokenInvalidError."""
    with pytest.raises(TokenInvalidError, match="Invalid token"):
        decode_token("not-a-valid-jwt-token")

    with pytest.raises(TokenInvalidError, match="Invalid token"):
        decode_token("")


def test_expected_type_enforcement():
    """Verify that decode_token enforces the expected token type."""
    access_token = create_access_token(subject="user-type")
    refresh_token = create_refresh_token(subject="user-type")

    # Access token cannot be decoded as refresh
    with pytest.raises(TokenInvalidError, match="Expected token type 'refresh'"):
        decode_token(access_token, expected_type=TOKEN_TYPE_REFRESH)

    # Refresh token cannot be decoded as access
    with pytest.raises(TokenInvalidError, match="Expected token type 'access'"):
        decode_token(refresh_token, expected_type=TOKEN_TYPE_ACCESS)


def test_token_missing_subject_rejected():
    """Verify that a token without 'sub' raises TokenInvalidError."""
    payload = {
        "type": TOKEN_TYPE_ACCESS,
        "exp": int((datetime.now(UTC) + timedelta(minutes=15)).timestamp()),
    }
    token = jwt.encode(payload, settings.secret_key, algorithm=settings.jwt_algorithm)

    with pytest.raises(TokenInvalidError, match="missing subject"):
        decode_token(token)


def test_rotate_refresh_token_success():
    """Verify single-use refresh token rotation issuing a new token pair."""
    user_id = str(uuid.uuid4())
    original_refresh = create_refresh_token(subject=user_id)
    orig_payload = decode_token(original_refresh)

    new_access, new_refresh = rotate_refresh_token(original_refresh)

    assert isinstance(new_access, str)
    assert isinstance(new_refresh, str)

    # Decode both tokens
    access_payload = decode_token(new_access, expected_type=TOKEN_TYPE_ACCESS)
    refresh_payload = decode_token(new_refresh, expected_type=TOKEN_TYPE_REFRESH)

    assert access_payload["sub"] == user_id
    assert refresh_payload["sub"] == user_id

    # The newly rotated refresh token must have a distinct jti
    assert refresh_payload["jti"] != orig_payload["jti"]
    assert new_refresh != original_refresh

    # Original token must now be revoked
    with pytest.raises(TokenInvalidError, match="Token has been revoked"):
        decode_token(original_refresh)


def test_rotate_refresh_token_fails_on_expired_token():
    """Verify rotate_refresh_token rejects expired tokens."""
    expired_refresh = create_refresh_token(
        subject="user-rot-exp", expires_delta=timedelta(seconds=-1)
    )

    with pytest.raises(TokenExpiredError, match="Token has expired"):
        rotate_refresh_token(expired_refresh)


def test_rotate_refresh_token_fails_on_access_token():
    """Verify rotate_refresh_token rejects access tokens."""
    access_token = create_access_token(subject="user-wrong-type")

    with pytest.raises(TokenInvalidError, match="Expected token type 'refresh'"):
        rotate_refresh_token(access_token)


def test_token_pydantic_schemas():
    """Verify Token, TokenPayload, and RefreshTokenRequest schemas."""
    # Token schema
    token_obj = Token(
        access_token="acc123",
        refresh_token="ref456",
        token_type="bearer",
    )
    assert token_obj.access_token == "acc123"
    assert token_obj.refresh_token == "ref456"
    assert token_obj.token_type == "bearer"

    # TokenPayload schema
    payload_obj = TokenPayload(
        sub="user-id-abc",
        type="access",
        exp=1700000000,
        iat=1699999000,
        jti="uuid-jti",
    )
    assert payload_obj.sub == "user-id-abc"
    assert payload_obj.type == "access"

    # RefreshTokenRequest schema
    req = RefreshTokenRequest(refresh_token="my-refresh-token")
    assert req.refresh_token == "my-refresh-token"
