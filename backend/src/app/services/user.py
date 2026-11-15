from sqlalchemy.orm import Session

from app.models.user import User
from app.schemas.user import UserProfileUpdate


def update_user_profile(
    db: Session,
    user: User,
    profile_update: UserProfileUpdate,
) -> User:
    """
    Update basic profile attributes for a user entity.

    :param db: Active database session.
    :param user: User model instance to update.
    :param profile_update: Validated profile update payload.
    :return: Updated User entity.
    """
    update_dict = profile_update.model_dump(exclude_unset=True)
    for field, value in update_dict.items():
        setattr(user, field, value)

    db.add(user)
    db.commit()
    db.refresh(user)
    return user
