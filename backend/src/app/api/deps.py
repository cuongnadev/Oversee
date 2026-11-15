import uuid
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import (
    TOKEN_TYPE_ACCESS,
    TokenExpiredError,
    TokenInvalidError,
    decode_token,
)
from app.db.session import get_db
from app.models.user import User

oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/api/v1/auth/login",
    auto_error=False,
)


def get_current_user(
    token: Annotated[str | None, Depends(oauth2_scheme)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    """
    Retrieve and validate the currently authenticated user from the Bearer token.

    :param token: JWT access token from Authorization header.
    :param db: Active database session.
    :return: Authenticated User entity.
    :raises HTTPException: 401 Unauthorized if token is missing, expired, invalid,
                           revoked, or if user does not exist or is inactive.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if not token:
        raise credentials_exception

    try:
        payload = decode_token(
            token,
            expected_type=TOKEN_TYPE_ACCESS,
            check_revocation=True,
        )
    except TokenExpiredError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from e
    except TokenInvalidError as e:
        raise credentials_exception from e

    sub = payload.get("sub")
    if not sub:
        raise credentials_exception

    try:
        user_id = uuid.UUID(sub)
    except ValueError as e:
        raise credentials_exception from e

    user = db.scalar(
        select(User).where(
            User.id == user_id,
            User.deleted_at.is_(None),
        )
    )

    if user is None:
        raise credentials_exception

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Inactive user.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return user


def get_current_active_user(
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    """Convenience dependency returning the active authenticated user."""
    return current_user
