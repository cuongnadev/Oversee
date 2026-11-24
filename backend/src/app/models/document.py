import uuid
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import BaseEntity

if TYPE_CHECKING:
    from app.models.project import Project
    from app.models.user import User


class Document(BaseEntity):
    """
    Document entity representing project knowledge base / markdown documentation.
    """

    __tablename__ = "documents"

    project_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    content: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        default=None,
    )
    author_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )

    # Relationships
    project: Mapped[Project] = relationship(
        "Project",
        foreign_keys=[project_id],
        passive_deletes=True,
        back_populates="documents",
    )
    author: Mapped[User] = relationship(
        "User",
        foreign_keys=[author_id],
    )

    def __repr__(self) -> str:
        return f"<Document(id={self.id}, project_id={self.project_id}, title='{self.title}')>"
