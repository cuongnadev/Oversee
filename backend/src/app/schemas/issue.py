import uuid
from datetime import datetime
from typing import Self

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.enums import IssuePriority, IssueStatus, IssueType, SprintStatus
from app.schemas.user import UserResponse


class IssueBase(BaseModel):
    """Base schema containing shared issue attributes."""

    title: str = Field(min_length=1, max_length=255)
    description: str | None = None
    type: IssueType = IssueType.TASK
    status: IssueStatus = IssueStatus.BACKLOG
    priority: IssuePriority = IssuePriority.MEDIUM
    estimate: float | None = Field(default=None, ge=0)
    backlog_rank: float = 0.0
    start_date: datetime | None = None
    end_date: datetime | None = None

    @field_validator("title")
    @classmethod
    def clean_title(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Issue title cannot be blank or contain only whitespace.")
        return cleaned

    @model_validator(mode="after")
    def validate_dates(self) -> Self:
        if (
            self.start_date is not None
            and self.end_date is not None
            and self.end_date < self.start_date
        ):
            raise ValueError("Issue end_date cannot be earlier than start_date.")
        return self


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
    estimate: float | None = Field(default=None, ge=0)
    assignee_id: uuid.UUID | None = None
    parent_id: uuid.UUID | None = None
    sprint_id: uuid.UUID | None = None
    backlog_rank: float | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    allow_open_subissues: bool = False

    @field_validator("title")
    @classmethod
    def clean_update_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Issue title cannot be blank or contain only whitespace.")
        return cleaned

    @model_validator(mode="after")
    def validate_update_dates(self) -> Self:
        if (
            self.start_date is not None
            and self.end_date is not None
            and self.end_date < self.start_date
        ):
            raise ValueError("Issue end_date cannot be earlier than start_date.")
        return self


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
    allow_open_subissues: bool = False


class BacklogAddIssuesRequest(BaseModel):
    """Schema for adding/moving existing issues into the product backlog."""

    issue_ids: list[uuid.UUID] | None = Field(
        default=None,
        description="List of issue IDs to move into the product backlog",
    )
    issue_id: uuid.UUID | None = Field(
        default=None,
        description="Single issue ID to move into the product backlog",
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


class BacklogReorderRequest(BaseModel):
    """Schema for moving/reordering an issue within the backlog."""

    issue_id: uuid.UUID = Field(
        ...,
        description="ID of the backlog issue to move",
    )
    previous_issue_id: uuid.UUID | None = Field(
        default=None,
        description="ID of the issue directly before the new position",
    )
    next_issue_id: uuid.UUID | None = Field(
        default=None,
        description="ID of the issue directly after the new position",
    )
    target_rank: float | None = Field(
        default=None,
        description="Explicit target rank value (optional)",
    )
    position: str | None = Field(
        default=None,
        description="Keyword position: 'top' or 'bottom'",
    )

    model_config = ConfigDict(extra="forbid")


class IssueRankUpdate(BaseModel):
    """Schema for updating issue rank."""

    previous_issue_id: uuid.UUID | None = None
    next_issue_id: uuid.UUID | None = None
    target_rank: float | None = None
    position: str | None = None

    model_config = ConfigDict(extra="forbid")


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
    assignee: UserResponse | None = None
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
    next_cursor: str | None = None
    has_more: bool = False


class BacklogSprintSummary(BaseModel):
    """Sprint metadata embedded in grouped backlog responses."""

    id: uuid.UUID
    project_id: uuid.UUID
    name: str
    goal: str | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    capacity: float | None = None
    status: SprintStatus
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class BacklogSprintGroup(BaseModel):
    """Sprint section in the grouped backlog view with completion metrics."""

    sprint: BacklogSprintSummary
    issues: list[IssueResponse]
    total_issues: int
    completed_issues: int
    total_story_points: float
    completed_story_points: float
    completion_percentage: float


class BacklogOverviewResponse(BaseModel):
    """Full sprint-grouped backlog response containing sprint buckets and unassigned backlog."""

    sprints: list[BacklogSprintGroup]
    backlog_issues: list[IssueResponse]
    total_issues: int
    backlog_total_issues: int
    backlog_completed_issues: int
    backlog_story_points: float
