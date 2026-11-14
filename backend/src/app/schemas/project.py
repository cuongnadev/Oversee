import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ProjectBase(BaseModel):
    """Base schema containing shared project attributes."""

    name: str = Field(min_length=1, max_length=255)
    key: str = Field(
        min_length=2,
        max_length=20,
        pattern=r"^[A-Z0-9]+$",
        description="Uppercase alphanumeric project key prefix (e.g. OVS, API)",
    )
    description: str | None = None


class ProjectCreate(ProjectBase):
    """Schema for creating a new project in a workspace."""

    workspace_id: uuid.UUID


class ProjectUpdate(BaseModel):
    """Schema for updating an existing project."""

    name: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None


class ProjectResponse(ProjectBase):
    """Schema returned to API clients representing a project."""

    id: uuid.UUID
    workspace_id: uuid.UUID
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
