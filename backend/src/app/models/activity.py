import uuid
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseAuditEntity

if TYPE_CHECKING:
    from app.models.issue import Issue
    from app.models.user import User


class Activity(BaseAuditEntity):
    """
    Activity entity recording audit log changes made to an issue
    (e.g. status changes, assignee reassignments, priority updates).
    """

    __tablename__ = "activities"

    issue_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("issues.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    actor_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    action: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        index=True,
        comment="Action type e.g. status_changed, assignee_changed, priority_changed",
    )
    old_value: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        default=None,
    )
    new_value: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        default=None,
    )

    # Relationships
    issue: Mapped[Issue] = relationship(
        "Issue",
        foreign_keys=[issue_id],
        back_populates="activities",
    )
    actor: Mapped[User] = relationship(
        "User",
        foreign_keys=[actor_id],
    )

    def __repr__(self) -> str:
        return (
            f"<Activity(id={self.id}, issue_id={self.issue_id}, "
            f"action='{self.action}', actor_id={self.actor_id})>"
        )
