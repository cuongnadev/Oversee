import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.enums import RoleType


class WorkspaceMemberCreate(BaseModel):
    """Schema for adding a member to a workspace."""

    user_id: uuid.UUID
    role: RoleType = RoleType.MEMBER


class WorkspaceMemberUpdate(BaseModel):
    """Schema for updating a member's role in a workspace."""

    role: RoleType


class WorkspaceMemberResponse(BaseModel):
    """Schema representing a workspace membership."""

    id: uuid.UUID
    workspace_id: uuid.UUID
    user_id: uuid.UUID
    role: RoleType
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ProjectMemberCreate(BaseModel):
    """Schema for adding a member to a project."""

    user_id: uuid.UUID
    role: RoleType = RoleType.MEMBER


class ProjectMemberUpdate(BaseModel):
    """Schema for updating a member's role in a project."""

    role: RoleType


class ProjectMemberResponse(BaseModel):
    """Schema representing a project membership."""

    id: uuid.UUID
    project_id: uuid.UUID
    user_id: uuid.UUID
    role: RoleType
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
