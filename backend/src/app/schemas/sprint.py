import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import SprintStatus


class SprintBase(BaseModel):
    """Base schema containing shared sprint attributes."""

    name: str = Field(min_length=1, max_length=255)
    goal: str | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    status: SprintStatus = SprintStatus.PLANNED


class SprintCreate(SprintBase):
    """Schema for creating a new sprint."""

    project_id: uuid.UUID


class SprintUpdate(BaseModel):
    """Schema for updating an existing sprint."""

    name: str | None = Field(default=None, min_length=1, max_length=255)
    goal: str | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    status: SprintStatus | None = None


class SprintResponse(SprintBase):
    """Schema returned to API clients representing a sprint."""

    id: uuid.UUID
    project_id: uuid.UUID
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
