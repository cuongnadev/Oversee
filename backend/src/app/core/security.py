import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import bcrypt
import jwt

from app.core.config import settings

TOKEN_TYPE_ACCESS = "access"
TOKEN_TYPE_REFRESH = "refresh"


class TokenError(Exception):
    """Base exception for all token-related errors."""


class TokenExpiredError(TokenError):
    """Raised when a JWT token has expired."""


class TokenInvalidError(TokenError):
    """Raised when a JWT token is invalid, malformed, or has the wrong type."""


# ---------------------------------------------------------------------------
# Password Hashing
# ---------------------------------------------------------------------------
def hash_password(password: str) -> str:
    """
    Hash a plain text password using bcrypt with a randomly generated salt.

    :param password: The plain text password to hash.
    :return: The bcrypt hashed password string.
    :raises ValueError: If the password is empty.
    """
    if not password:
        raise ValueError("Password cannot be empty.")

    password_bytes = password.encode("utf-8")
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password_bytes, salt)
    return hashed.decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verify a plain text password against a stored bcrypt hashed password.

    :param plain_password: The plain text password candidate.
    :param hashed_password: The bcrypt hash stored in the database.
    :return: True if the password matches the hash, False otherwise.
    """
    if not plain_password or not hashed_password:
        return False

    try:
        plain_bytes = plain_password.encode("utf-8")
        hash_bytes = hashed_password.encode("utf-8")
        return bcrypt.checkpw(plain_bytes, hash_bytes)
    except ValueError, TypeError:
        return False


# ---------------------------------------------------------------------------
# JWT Token Management
# ---------------------------------------------------------------------------
def create_access_token(
    subject: str | uuid.UUID,
    expires_delta: timedelta | None = None,
    extra_claims: dict[str, Any] | None = None,
) -> str:
    """
    Generate a signed JWT access token for a subject (user ID).

    :param subject: The user identifier (UUID or str) stored in the 'sub' claim.
    :param expires_delta: Optional custom lifetime. Defaults to settings.access_token_expire_minutes.
    :param extra_claims: Optional dictionary of additional claims to include in the payload.
    :return: Encoded JWT string.
    """
    now = datetime.now(UTC)
    if expires_delta is not None:
        expire = now + expires_delta
    else:
        expire = now + timedelta(minutes=settings.access_token_expire_minutes)

    payload: dict[str, Any] = {
        "sub": str(subject),
        "type": TOKEN_TYPE_ACCESS,
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
        "jti": str(uuid.uuid4()),
    }

    if extra_claims:
        # Don't let extra claims overwrite standard reserved claims
        for k, v in extra_claims.items():
            if k not in payload:
                payload[k] = v

    return jwt.encode(payload, settings.secret_key, algorithm=settings.jwt_algorithm)


def create_refresh_token(
    subject: str | uuid.UUID,
    expires_delta: timedelta | None = None,
    extra_claims: dict[str, Any] | None = None,
) -> str:
    """
    Generate a signed JWT refresh token for a subject (user ID).

    :param subject: The user identifier (UUID or str) stored in the 'sub' claim.
    :param expires_delta: Optional custom lifetime. Defaults to settings.refresh_token_expire_days.
    :param extra_claims: Optional dictionary of additional claims to include in the payload.
    :return: Encoded JWT string.
    """
    now = datetime.now(UTC)
    if expires_delta is not None:
        expire = now + expires_delta
    else:
        expire = now + timedelta(days=settings.refresh_token_expire_days)

    payload: dict[str, Any] = {
        "sub": str(subject),
        "type": TOKEN_TYPE_REFRESH,
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
        "jti": str(uuid.uuid4()),
    }

    if extra_claims:
        for k, v in extra_claims.items():
            if k not in payload:
                payload[k] = v

    return jwt.encode(payload, settings.secret_key, algorithm=settings.jwt_algorithm)


def decode_token(token: str, expected_type: str | None = None) -> dict[str, Any]:
    """
    Decode and validate a signed JWT token.

    :param token: The encoded JWT token string.
    :param expected_type: Optional expected token type ('access' or 'refresh').
    :return: Decoded payload dictionary.
    :raises TokenExpiredError: If the token expiration time ('exp') is in the past.
    :raises TokenInvalidError: If the token is malformed, has invalid signature, or wrong type.
    """
    try:
        payload = jwt.decode(
            token,
            settings.secret_key,
            algorithms=[settings.jwt_algorithm],
        )
    except jwt.ExpiredSignatureError as e:
        raise TokenExpiredError("Token has expired.") from e
    except jwt.InvalidTokenError as e:
        raise TokenInvalidError("Invalid token.") from e

    if expected_type is not None:
        actual_type = payload.get("type")
        if actual_type != expected_type:
            raise TokenInvalidError(
                f"Expected token type '{expected_type}', got '{actual_type}'."
            )

    if not payload.get("sub"):
        raise TokenInvalidError("Token payload missing subject ('sub').")

    return payload


def rotate_refresh_token(refresh_token: str) -> tuple[str, str]:
    """
    Validate a refresh token and issue a fresh pair of (access_token, refresh_token).
    Implements single-use rotation: each refresh results in a newly minted refresh token.

    :param refresh_token: The existing refresh token string.
    :return: A tuple of (new_access_token, new_refresh_token).
    :raises TokenExpiredError: If the refresh token has expired.
    :raises TokenInvalidError: If the refresh token is invalid or not of type 'refresh'.
    """
    payload = decode_token(refresh_token, expected_type=TOKEN_TYPE_REFRESH)
    subject = payload["sub"]

    new_access_token = create_access_token(subject=subject)
    new_refresh_token = create_refresh_token(subject=subject)

    return new_access_token, new_refresh_token
