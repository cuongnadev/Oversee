import uuid
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseEntity

if TYPE_CHECKING:
    from app.models.workspace import Workspace


class Project(BaseEntity):
    """
    Project entity belonging to a single Workspace.
    Groups issues, tasks, sprints, and project members.
    """

    __tablename__ = "projects"
    __table_args__ = (
        UniqueConstraint("workspace_id", "key", name="uq_projects_workspace_key"),
    )

    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    key: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        comment="Project key prefix for issues (e.g. OVS, API)",
    )
    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        default=None,
    )
    workspace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("workspaces.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Relationships
    workspace: Mapped[Workspace] = relationship(
        "Workspace",
        foreign_keys=[workspace_id],
        backref="projects",
    )

    def __repr__(self) -> str:
        return f"<Project(id={self.id}, key='{self.key}', name='{self.name}')>"
