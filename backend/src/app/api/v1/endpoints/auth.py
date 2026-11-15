from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.auth import LoginRequest, LogoutResponse, RegisterRequest
from app.schemas.token import RefreshTokenRequest, Token
from app.schemas.user import UserResponse
from app.services.auth import (
    authenticate_user,
    logout_user,
    refresh_tokens,
    register_user,
)

router = APIRouter()


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user account",
    description="Registers a new user account with validated email and password strength. Returns user details without password.",
)
def register(
    request: RegisterRequest,
    db: Annotated[Session, Depends(get_db)],
) -> UserResponse:
    """Register a new user account."""
    user = register_user(db, request)
    return UserResponse.model_validate(user)


@router.post(
    "/login",
    response_model=Token,
    status_code=status.HTTP_200_OK,
    summary="User login",
    description="Authenticates user with email and password, issuing a JWT access token and refresh token.",
)
def login(
    request: LoginRequest,
    db: Annotated[Session, Depends(get_db)],
) -> Token:
    """Authenticate and issue access and refresh tokens."""
    return authenticate_user(db, request)


@router.post(
    "/refresh",
    response_model=Token,
    status_code=status.HTTP_200_OK,
    summary="Rotate refresh token",
    description="Exchanges a valid refresh token for a newly issued access token and rotated refresh token.",
)
def refresh(
    request: RefreshTokenRequest,
) -> Token:
    """Rotate refresh token to obtain a new token pair."""
    return refresh_tokens(request.refresh_token)


@router.post(
    "/logout",
    response_model=LogoutResponse,
    status_code=status.HTTP_200_OK,
    summary="User logout",
    description="Revokes the provided refresh token, invalidating it from future token rotation.",
)
def logout(
    request: RefreshTokenRequest,
) -> LogoutResponse:
    """Revoke refresh token and log out user."""
    logout_user(request.refresh_token)
    return LogoutResponse(message="Successfully logged out.")
