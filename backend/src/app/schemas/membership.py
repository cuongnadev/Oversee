import uuid
from datetime import datetime
from typing import Self

from pydantic import BaseModel, ConfigDict, EmailStr, model_validator

from app.models.enums import RoleType
from app.schemas.user import UserResponse


class WorkspaceMemberCreate(BaseModel):
    """Schema for adding a member to a workspace."""

    model_config = ConfigDict(extra="forbid")

    user_id: uuid.UUID | None = None
    email: EmailStr | None = None
    role: RoleType = RoleType.MEMBER

    @model_validator(mode="after")
    def validate_identifier(self) -> Self:
        if self.user_id is None and self.email is None:
            raise ValueError("Either user_id or email must be provided.")
        return self


class WorkspaceMemberUpdate(BaseModel):
    """Schema for updating a member's role in a workspace."""

    model_config = ConfigDict(extra="forbid")

    role: RoleType


class WorkspaceMemberResponse(BaseModel):
    """Schema representing a workspace membership."""

    id: uuid.UUID
    workspace_id: uuid.UUID
    user_id: uuid.UUID
    role: RoleType
    created_at: datetime
    updated_at: datetime
    user: UserResponse | None = None

    model_config = ConfigDict(from_attributes=True)


class ProjectMemberCreate(BaseModel):
    """Schema for adding a member to a project."""

    model_config = ConfigDict(extra="forbid")

    user_id: uuid.UUID | None = None
    email: EmailStr | None = None
    role: RoleType = RoleType.MEMBER

    @model_validator(mode="after")
    def validate_identifier(self) -> Self:
        if self.user_id is None and self.email is None:
            raise ValueError("Either user_id or email must be provided.")
        return self


class ProjectMemberUpdate(BaseModel):
    """Schema for updating a member's role in a project."""

    model_config = ConfigDict(extra="forbid")

    role: RoleType


class ProjectMemberResponse(BaseModel):
    """Schema representing a project membership."""

    id: uuid.UUID
    project_id: uuid.UUID
    user_id: uuid.UUID
    role: RoleType
    created_at: datetime
    updated_at: datetime
    user: UserResponse | None = None

    model_config = ConfigDict(from_attributes=True)
