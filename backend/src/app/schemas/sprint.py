import uuid
from datetime import datetime
from typing import Self

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.enums import SprintStatus


class SprintBase(BaseModel):
    """Base schema containing shared sprint attributes."""

    name: str = Field(min_length=1, max_length=255)
    goal: str | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    capacity: float | None = Field(default=None, ge=0)
    status: SprintStatus = SprintStatus.PLANNED

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Sprint name cannot be blank or contain only whitespace.")
        return cleaned

    @model_validator(mode="after")
    def validate_dates(self) -> Self:
        if (
            self.start_date is not None
            and self.end_date is not None
            and self.start_date >= self.end_date
        ):
            raise ValueError("Sprint start_date must be strictly before end_date.")
        return self


class SprintCreate(SprintBase):
    """Schema for creating a new sprint."""

    project_id: uuid.UUID | None = None

    model_config = ConfigDict(extra="forbid")


class SprintUpdate(BaseModel):
    """Schema for updating an existing sprint."""

    name: str | None = Field(default=None, min_length=1, max_length=255)
    goal: str | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    capacity: float | None = Field(default=None, ge=0)
    status: SprintStatus | None = None

    model_config = ConfigDict(extra="forbid")

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str | None) -> str | None:
        if value is not None:
            cleaned = value.strip()
            if not cleaned:
                raise ValueError(
                    "Sprint name cannot be blank or contain only whitespace."
                )
            return cleaned
        return value

    @model_validator(mode="after")
    def validate_dates(self) -> Self:
        if (
            self.start_date is not None
            and self.end_date is not None
            and self.start_date >= self.end_date
        ):
            raise ValueError("Sprint start_date must be strictly before end_date.")
        return self


class SprintResponse(SprintBase):
    """Schema returned to API clients representing a sprint."""

    id: uuid.UUID
    project_id: uuid.UUID
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class SprintAddIssuesRequest(BaseModel):
    """Schema for adding/moving issues into a sprint."""

    issue_ids: list[uuid.UUID] | None = Field(
        default=None,
        description="List of issue IDs to assign to the sprint",
    )
    issue_id: uuid.UUID | None = Field(
        default=None,
        description="Single issue ID to assign to the sprint",
    )

    model_config = ConfigDict(extra="forbid")

    @model_validator(mode="after")
    def validate_ids(self) -> Self:
        if not self.issue_ids and not self.issue_id:
            raise ValueError("Either 'issue_ids' or 'issue_id' must be provided.")
        return self

    def get_all_issue_ids(self) -> list[uuid.UUID]:
        ids: list[uuid.UUID] = []
        if self.issue_ids:
            ids.extend(self.issue_ids)
        if self.issue_id and self.issue_id not in ids:
            ids.append(self.issue_id)
        return ids


class SprintRemoveIssuesRequest(BaseModel):
    """Schema for removing issues from a sprint (returning to backlog)."""

    issue_ids: list[uuid.UUID] | None = Field(
        default=None,
        description="List of issue IDs to remove from the sprint",
    )
    issue_id: uuid.UUID | None = Field(
        default=None,
        description="Single issue ID to remove from the sprint",
    )

    model_config = ConfigDict(extra="forbid")

    @model_validator(mode="after")
    def validate_ids(self) -> Self:
        if not self.issue_ids and not self.issue_id:
            raise ValueError("Either 'issue_ids' or 'issue_id' must be provided.")
        return self

    def get_all_issue_ids(self) -> list[uuid.UUID]:
        ids: list[uuid.UUID] = []
        if self.issue_ids:
            ids.extend(self.issue_ids)
        if self.issue_id and self.issue_id not in ids:
            ids.append(self.issue_id)
        return ids


# Forward reference for IssueResponse in SprintPlanningResponse
from app.schemas.issue import IssueResponse


class SprintPlanningResponse(BaseModel):
    """Schema for sprint planning summary including capacity and estimate metrics."""

    sprint: SprintResponse
    issues: list[IssueResponse]
    total_issues: int
    total_estimate: float
    capacity: float | None = None
    is_over_capacity: bool = False
    warning: str | None = None

    model_config = ConfigDict(from_attributes=True)
