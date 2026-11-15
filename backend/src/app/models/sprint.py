import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, Enum, Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseEntity
from app.models.enums import SprintStatus

if TYPE_CHECKING:
    from app.models.issue import Issue
    from app.models.project import Project


class Sprint(BaseEntity):
    """
    Sprint entity representing a fixed-time development iteration
    containing prioritized issues.
    """

    __tablename__ = "sprints"

    project_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    goal: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        default=None,
    )
    start_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        default=None,
    )
    end_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        default=None,
    )
    capacity: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
        default=None,
        comment="Planned capacity limit in story points or hours",
    )
    status: Mapped[SprintStatus] = mapped_column(
        Enum(SprintStatus, native_enum=False, length=50),
        default=SprintStatus.PLANNED,
        nullable=False,
        index=True,
    )

    # Relationships
    project: Mapped[Project] = relationship(
        "Project",
        foreign_keys=[project_id],
        passive_deletes=True,
        back_populates="sprints",
    )
    issues: Mapped[list[Issue]] = relationship(
        "Issue",
        foreign_keys="Issue.sprint_id",
        back_populates="sprint",
    )

    def __repr__(self) -> str:
        return (
            f"<Sprint(id={self.id}, name='{self.name}', status='{self.status.value}')>"
        )
