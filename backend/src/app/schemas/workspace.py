import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class WorkspaceBase(BaseModel):
    """Base schema containing shared workspace attributes."""

    name: str = Field(min_length=1, max_length=255)
    slug: str = Field(
        min_length=1,
        max_length=100,
        pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$",
        description="URL-friendly slug (lowercase letters, numbers, and hyphens)",
    )
    description: str | None = None


class WorkspaceCreate(WorkspaceBase):
    """Schema for creating a new workspace."""


class WorkspaceUpdate(BaseModel):
    """Schema for updating an existing workspace."""

    name: str | None = Field(default=None, min_length=1, max_length=255)
    slug: str | None = Field(
        default=None,
        min_length=1,
        max_length=100,
        pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$",
    )
    description: str | None = None


class WorkspaceResponse(WorkspaceBase):
    """Schema returned to API clients representing a workspace."""

    id: uuid.UUID
    owner_id: uuid.UUID
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
