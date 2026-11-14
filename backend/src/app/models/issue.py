import uuid
from typing import TYPE_CHECKING

from sqlalchemy import Enum, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseEntity
from app.models.enums import IssuePriority, IssueStatus, IssueType

if TYPE_CHECKING:
    from app.models.project import Project
    from app.models.user import User


class Issue(BaseEntity):
    """
    Issue entity representing tasks, stories, bugs, epics, or subtasks.
    Supports parent-child hierarchy and assignment to project members.
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

    def __repr__(self) -> str:
        return (
            f"<Issue(id={self.id}, number={self.issue_number}, "
            f"title='{self.title}', status='{self.status.value}')>"
        )
