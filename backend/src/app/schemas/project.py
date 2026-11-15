import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


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

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Project name cannot be blank or contain only whitespace.")
        return cleaned

    @field_validator("key")
    @classmethod
    def clean_key(cls, value: str) -> str:
        cleaned = value.strip().upper()
        if not cleaned:
            raise ValueError("Project key cannot be blank.")
        return cleaned


class ProjectCreate(ProjectBase):
    """Schema for creating a new project in a workspace."""

    model_config = ConfigDict(extra="forbid")

    workspace_id: uuid.UUID | None = None


class ProjectUpdate(BaseModel):
    """Schema for updating an existing project."""

    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=255)
    key: str | None = Field(
        default=None,
        min_length=2,
        max_length=20,
        pattern=r"^[A-Z0-9]+$",
        description="Uppercase alphanumeric project key prefix",
    )
    description: str | None = None

    @field_validator("name")
    @classmethod
    def clean_update_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Project name cannot be blank or contain only whitespace.")
        return cleaned

    @field_validator("key")
    @classmethod
    def clean_update_key(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip().upper()
        if not cleaned:
            raise ValueError("Project key cannot be blank.")
        return cleaned


class ProjectResponse(ProjectBase):
    """Schema returned to API clients representing a project."""

    id: uuid.UUID
    workspace_id: uuid.UUID
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class ProjectPageResponse(BaseModel):
    """Paginated list of projects."""

    items: list[ProjectResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
