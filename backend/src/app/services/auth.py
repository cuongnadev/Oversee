from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import (
    TokenExpiredError,
    TokenInvalidError,
    create_access_token,
    create_refresh_token,
    hash_password,
    revoke_token,
    rotate_refresh_token,
    verify_password,
)
from app.models.user import User
from app.schemas.auth import LoginRequest, RegisterRequest
from app.schemas.token import Token


def register_user(db: Session, request: RegisterRequest) -> User:
    """
    Register a new user account.

    :param db: Active database session.
    :param request: Validated registration payload.
    :return: Newly created User entity.
    :raises HTTPException: 409 Conflict if email is already registered.
    """
    normalized_email = request.email.lower().strip()

    # Check for duplicate email
    existing_user = db.scalar(select(User).where(User.email == normalized_email))
    if existing_user is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email is already registered.",
        )

    # Hash the plain-text password using bcrypt
    hashed = hash_password(request.password)

    # Persist the new user
    user = User(
        email=normalized_email,
        hashed_password=hashed,
        full_name=request.full_name,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def authenticate_user(db: Session, request: LoginRequest) -> Token:
    """
    Authenticate a user with email and password, issuing access and refresh tokens.

    :param db: Active database session.
    :param request: Login credentials.
    :return: Token schema containing access_token and refresh_token.
    :raises HTTPException: 401 Unauthorized with generic message on invalid credentials or inactive user.
    """
    normalized_email = request.email.lower().strip()

    user = db.scalar(
        select(User).where(
            User.email == normalized_email,
            User.deleted_at.is_(None),
        )
    )

    # Generic error message to prevent account enumeration attacks
    generic_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Incorrect email or password.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if user is None:
        raise generic_error

    if not user.is_active:
        raise generic_error

    if not verify_password(request.password, user.hashed_password):
        raise generic_error

    access_token = create_access_token(subject=user.id)
    refresh_token = create_refresh_token(subject=user.id)

    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
    )


def logout_user(refresh_token: str) -> None:
    """
    Revoke a refresh token on logout, preventing its future usage.

    :param refresh_token: The refresh token to invalidate.
    :raises HTTPException: 401 Unauthorized if the token is invalid or malformed.
    """
    try:
        revoke_token(refresh_token)
    except TokenInvalidError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from e
    except TokenExpiredError:
        # If the token is already expired, it is already effectively unusable
        pass


def refresh_tokens(refresh_token: str) -> Token:
    """
    Rotate a refresh token to generate a fresh pair of (access_token, refresh_token).

    :param refresh_token: The existing refresh token.
    :return: Token schema with newly minted access and refresh tokens.
    :raises HTTPException: 401 Unauthorized if the token has expired or is invalid.
    """
    try:
        new_access, new_refresh = rotate_refresh_token(refresh_token)
        return Token(
            access_token=new_access,
            refresh_token=new_refresh,
            token_type="bearer",
        )
    except TokenExpiredError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token has expired.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from e
    except TokenInvalidError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"},
        ) from e
