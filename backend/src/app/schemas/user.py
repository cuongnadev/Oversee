import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserBase(BaseModel):
    """Base schema containing shared user attributes."""

    email: EmailStr
    full_name: str = Field(min_length=1, max_length=255)
    avatar_url: str | None = None
    is_active: bool = True


class UserCreate(UserBase):
    """Schema for creating a new user with plain-text password."""

    password: str = Field(min_length=8)


class UserUpdate(BaseModel):
    """Schema for updating an existing user's profile."""

    email: EmailStr | None = None
    full_name: str | None = Field(default=None, min_length=1, max_length=255)
    avatar_url: str | None = None
    password: str | None = Field(default=None, min_length=8)
    is_active: bool | None = None


class UserResponse(UserBase):
    """Schema returned to API clients representing a user."""

    id: uuid.UUID
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
