from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.user import UserProfileUpdate, UserResponse
from app.services.user import update_user_profile

router = APIRouter()


@router.get(
    "/me",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Get current user profile",
    description="Retrieve the profile details of the currently authenticated user.",
)
def get_current_user_profile(
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    """Return the currently authenticated user."""
    return current_user


@router.patch(
    "/me",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Update current user profile",
    description=(
        "Update basic profile information (such as full name or avatar URL) "
        "for the currently authenticated user."
    ),
)
def update_current_user_profile(
    update_data: UserProfileUpdate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    """Update profile information of the currently authenticated user."""
    return update_user_profile(db=db, user=current_user, profile_update=update_data)
