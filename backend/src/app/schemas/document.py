import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class DocumentBase(BaseModel):
    """Base schema containing shared document attributes."""

    title: str = Field(min_length=1, max_length=255)
    content: str | None = None

    @field_validator("title")
    @classmethod
    def clean_title(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Document title cannot be blank or contain only whitespace.")
        return cleaned


class DocumentCreate(DocumentBase):
    """Schema for creating a new document."""

    project_id: uuid.UUID | None = None

    model_config = ConfigDict(extra="forbid")


class DocumentUpdate(BaseModel):
    """Schema for updating an existing document."""

    title: str | None = Field(default=None, min_length=1, max_length=255)
    content: str | None = None

    model_config = ConfigDict(extra="forbid")

    @field_validator("title")
    @classmethod
    def clean_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Document title cannot be blank or contain only whitespace.")
        return cleaned


class DocumentResponse(DocumentBase):
    """Schema returned to API clients representing a document."""

    id: uuid.UUID
    project_id: uuid.UUID
    author_id: uuid.UUID
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
