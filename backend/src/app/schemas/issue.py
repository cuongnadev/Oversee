import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import IssuePriority, IssueStatus, IssueType


class IssueBase(BaseModel):
    """Base schema containing shared issue attributes."""

    title: str = Field(min_length=1, max_length=255)
    description: str | None = None
    type: IssueType = IssueType.TASK
    status: IssueStatus = IssueStatus.BACKLOG
    priority: IssuePriority = IssuePriority.MEDIUM
    backlog_rank: float = 0.0


class IssueCreate(IssueBase):
    """Schema for creating a new issue."""

    project_id: uuid.UUID
    issue_number: int = Field(ge=1)
    assignee_id: uuid.UUID | None = None
    parent_id: uuid.UUID | None = None
    sprint_id: uuid.UUID | None = None


class IssueUpdate(BaseModel):
    """Schema for updating an existing issue."""

    title: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    type: IssueType | None = None
    status: IssueStatus | None = None
    priority: IssuePriority | None = None
    assignee_id: uuid.UUID | None = None
    parent_id: uuid.UUID | None = None
    sprint_id: uuid.UUID | None = None
    backlog_rank: float | None = None


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

    model_config = ConfigDict(from_attributes=True)
