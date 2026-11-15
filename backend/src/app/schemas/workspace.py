import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


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

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError(
                "Workspace name cannot be blank or contain only whitespace."
            )
        return cleaned

    @field_validator("slug")
    @classmethod
    def clean_slug(cls, value: str) -> str:
        cleaned = value.strip().lower()
        if not cleaned:
            raise ValueError("Workspace slug cannot be blank.")
        return cleaned


class WorkspaceCreate(WorkspaceBase):
    """Schema for creating a new workspace."""

    model_config = ConfigDict(extra="forbid")


class WorkspaceUpdate(BaseModel):
    """Schema for updating an existing workspace."""

    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=255)
    slug: str | None = Field(
        default=None,
        min_length=1,
        max_length=100,
        pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$",
    )
    description: str | None = None

    @field_validator("name")
    @classmethod
    def clean_update_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        if not cleaned:
            raise ValueError(
                "Workspace name cannot be blank or contain only whitespace."
            )
        return cleaned

    @field_validator("slug")
    @classmethod
    def clean_update_slug(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip().lower()
        if not cleaned:
            raise ValueError("Workspace slug cannot be blank.")
        return cleaned


class WorkspaceResponse(WorkspaceBase):
    """Schema returned to API clients representing a workspace."""

    id: uuid.UUID
    owner_id: uuid.UUID
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
