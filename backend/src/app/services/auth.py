from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models.user import User
from app.schemas.auth import RegisterRequest


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
