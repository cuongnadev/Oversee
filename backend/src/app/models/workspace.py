import uuid
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseEntity

if TYPE_CHECKING:
    from app.models.membership import WorkspaceMember
    from app.models.project import Project
    from app.models.user import User


class Workspace(BaseEntity):
    """
    Workspace entity representing the top-level organization or team boundary.
    Contains projects and members.
    """

    __tablename__ = "workspaces"

    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    slug: Mapped[str] = mapped_column(
        String(100),
        unique=True,
        index=True,
        nullable=False,
    )
    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        default=None,
    )
    owner_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )

    # Relationships
    owner: Mapped[User] = relationship(
        "User",
        foreign_keys=[owner_id],
        backref="owned_workspaces",
    )
    projects: Mapped[list[Project]] = relationship(
        "Project",
        cascade="all, delete-orphan",
        passive_deletes=True,
        back_populates="workspace",
    )
    members: Mapped[list[WorkspaceMember]] = relationship(
        "WorkspaceMember",
        cascade="all, delete-orphan",
        passive_deletes=True,
        back_populates="workspace",
    )

    def __repr__(self) -> str:
        return f"<Workspace(id={self.id}, slug='{self.slug}', name='{self.name}')>"
