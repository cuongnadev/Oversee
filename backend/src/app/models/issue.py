import uuid
from datetime import datetime
from typing import TYPE_CHECKING, Any

from sqlalchemy import (
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseEntity
from app.models.enums import IssuePriority, IssueStatus, IssueType

if TYPE_CHECKING:
    from app.models.activity import Activity
    from app.models.project import Project
    from app.models.sprint import Sprint
    from app.models.user import User


class Issue(BaseEntity):
    """
    Issue entity representing tasks, stories, bugs, epics, or subtasks.
    Supports parent-child hierarchy, sprint iterations, and product backlog ranking.
    """

    __tablename__ = "issues"
    __table_args__ = (
        UniqueConstraint("project_id", "issue_number", name="uq_issues_project_number"),
    )

    project_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    issue_number: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="Sequential number per project (e.g. 1 for OVS-1)",
    )
    title: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        default=None,
    )
    type: Mapped[IssueType] = mapped_column(
        Enum(IssueType, native_enum=False, length=50),
        default=IssueType.TASK,
        nullable=False,
    )
    status: Mapped[IssueStatus] = mapped_column(
        Enum(IssueStatus, native_enum=False, length=50),
        default=IssueStatus.BACKLOG,
        nullable=False,
        index=True,
    )
    priority: Mapped[IssuePriority] = mapped_column(
        Enum(IssuePriority, native_enum=False, length=50),
        default=IssuePriority.MEDIUM,
        nullable=False,
    )
    reporter_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    assignee_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        default=None,
    )
    parent_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("issues.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
        default=None,
    )
    sprint_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("sprints.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        default=None,
    )
    estimate: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
        default=None,
        comment="Story points or time estimate for sprint planning",
    )
    backlog_rank: Mapped[float] = mapped_column(
        Float,
        default=0.0,
        server_default="0.0",
        nullable=False,
        index=True,
        comment="Ordering position within the backlog",
    )
    start_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        default=None,
        comment="Planned start date for timeline/calendar scheduling",
    )
    end_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        default=None,
        comment="Planned due/end date for timeline/calendar scheduling",
    )

    def __init__(self, **kwargs: Any) -> None:
        kwargs.setdefault("backlog_rank", 0.0)
        super().__init__(**kwargs)

    # Relationships
    project: Mapped[Project] = relationship(
        "Project",
        foreign_keys=[project_id],
        passive_deletes=True,
        back_populates="issues",
    )
    reporter: Mapped[User] = relationship(
        "User",
        foreign_keys=[reporter_id],
        backref="reported_issues",
    )
    assignee: Mapped[User | None] = relationship(
        "User",
        foreign_keys=[assignee_id],
        backref="assigned_issues",
    )
    parent: Mapped[Issue | None] = relationship(
        "Issue",
        remote_side="Issue.id",
        foreign_keys=[parent_id],
        passive_deletes=True,
        back_populates="sub_issues",
    )
    sub_issues: Mapped[list[Issue]] = relationship(
        "Issue",
        cascade="all, delete-orphan",
        passive_deletes=True,
        back_populates="parent",
    )
    sprint: Mapped[Sprint | None] = relationship(
        "Sprint",
        foreign_keys=[sprint_id],
        back_populates="issues",
    )
    activities: Mapped[list[Activity]] = relationship(
        "Activity",
        cascade="all, delete-orphan",
        passive_deletes=True,
        back_populates="issue",
        order_by="Activity.created_at.asc()",
    )

    @property
    def is_backlog(self) -> bool:
        """Returns True if the issue is in the product backlog (unassigned to any sprint)."""
        return self.sprint_id is None

    def __repr__(self) -> str:
        return (
            f"<Issue(id={self.id}, number={self.issue_number}, "
            f"title='{self.title}', status='{self.status.value}')>"
        )
