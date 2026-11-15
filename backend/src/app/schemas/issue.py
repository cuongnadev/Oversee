import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.enums import IssuePriority, IssueStatus, IssueType


class IssueBase(BaseModel):
    """Base schema containing shared issue attributes."""

    title: str = Field(min_length=1, max_length=255)
    description: str | None = None
    type: IssueType = IssueType.TASK
    status: IssueStatus = IssueStatus.BACKLOG
    priority: IssuePriority = IssuePriority.MEDIUM
    backlog_rank: float = 0.0

    @field_validator("title")
    @classmethod
    def clean_title(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Issue title cannot be blank or contain only whitespace.")
        return cleaned


class IssueCreate(IssueBase):
    """Schema for creating a new issue."""

    model_config = ConfigDict(extra="forbid")

    project_id: uuid.UUID | None = None
    issue_number: int | None = Field(default=None, ge=1)
    assignee_id: uuid.UUID | None = None
    parent_id: uuid.UUID | None = None
    sprint_id: uuid.UUID | None = None


class IssueUpdate(BaseModel):
    """Schema for updating an existing issue."""

    model_config = ConfigDict(extra="forbid")

    title: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    type: IssueType | None = None
    status: IssueStatus | None = None
    priority: IssuePriority | None = None
    assignee_id: uuid.UUID | None = None
    parent_id: uuid.UUID | None = None
    sprint_id: uuid.UUID | None = None
    backlog_rank: float | None = None

    @field_validator("title")
    @classmethod
    def clean_update_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Issue title cannot be blank or contain only whitespace.")
        return cleaned


class IssueAssigneeUpdate(BaseModel):
    """Schema for updating issue assignee."""

    model_config = ConfigDict(extra="forbid")

    assignee_id: uuid.UUID | None = None


class IssuePriorityUpdate(BaseModel):
    """Schema for updating issue priority."""

    model_config = ConfigDict(extra="forbid")

    priority: IssuePriority


class IssueStatusUpdate(BaseModel):
    """Schema for updating issue status."""

    model_config = ConfigDict(extra="forbid")

    status: IssueStatus


class IssueActivityResponse(BaseModel):
    """Schema representing an activity log entry for an issue."""

    id: uuid.UUID
    issue_id: uuid.UUID
    actor_id: uuid.UUID
    action: str
    old_value: str | None = None
    new_value: str | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class IssueHierarchySummary(BaseModel):
    """Compact representation of an issue in parent-child relationships."""

    id: uuid.UUID
    project_id: uuid.UUID
    issue_number: int
    title: str
    type: IssueType
    status: IssueStatus
    priority: IssuePriority
    assignee_id: uuid.UUID | None = None

    model_config = ConfigDict(from_attributes=True)


class IssueResponse(IssueBase):
    """Schema returned to API clients representing an issue."""

    id: uuid.UUID
    project_id: uuid.UUID
    issue_number: int
    reporter_id: uuid.UUID
    assignee_id: uuid.UUID | None = None
    parent_id: uuid.UUID | None = None
    sprint_id: uuid.UUID | None = None
    is_backlog: bool = True
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None
    parent: IssueHierarchySummary | None = None
    sub_issues: list[IssueHierarchySummary] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class IssuePageResponse(BaseModel):
    """Paginated list of issues."""

    items: list[IssueResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
