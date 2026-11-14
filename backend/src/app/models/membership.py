import uuid
from typing import TYPE_CHECKING

from sqlalchemy import Enum, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, backref, mapped_column, relationship

from app.models.base import BaseAuditEntity
from app.models.enums import RoleType

if TYPE_CHECKING:
    from app.models.project import Project
    from app.models.user import User
    from app.models.workspace import Workspace


class WorkspaceMember(BaseAuditEntity):
    """
    Junction entity representing membership of a User within a Workspace,
    along with their assigned role.
    """

    __tablename__ = "workspace_members"
    __table_args__ = (
        UniqueConstraint("workspace_id", "user_id", name="uq_workspace_members_user"),
    )

    workspace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("workspaces.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    role: Mapped[RoleType] = mapped_column(
        Enum(RoleType, native_enum=False, length=50),
        default=RoleType.MEMBER,
        nullable=False,
    )

    # Relationships
    workspace: Mapped[Workspace] = relationship(
        "Workspace",
        foreign_keys=[workspace_id],
        passive_deletes=True,
        back_populates="members",
    )
    user: Mapped[User] = relationship(
        "User",
        foreign_keys=[user_id],
        passive_deletes=True,
        backref=backref("workspace_memberships", passive_deletes=True),
    )

    def __repr__(self) -> str:
        return (
            f"<WorkspaceMember(workspace_id={self.workspace_id}, "
            f"user_id={self.user_id}, role='{self.role.value}')>"
        )


class ProjectMember(BaseAuditEntity):
    """
    Junction entity representing membership of a User within a Project,
    along with their assigned role.
    """

    __tablename__ = "project_members"
    __table_args__ = (
        UniqueConstraint("project_id", "user_id", name="uq_project_members_user"),
    )

    project_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    role: Mapped[RoleType] = mapped_column(
        Enum(RoleType, native_enum=False, length=50),
        default=RoleType.MEMBER,
        nullable=False,
    )

    # Relationships
    project: Mapped[Project] = relationship(
        "Project",
        foreign_keys=[project_id],
        passive_deletes=True,
        back_populates="members",
    )
    user: Mapped[User] = relationship(
        "User",
        foreign_keys=[user_id],
        passive_deletes=True,
        backref=backref("project_memberships", passive_deletes=True),
    )

    def __repr__(self) -> str:
        return (
            f"<ProjectMember(project_id={self.project_id}, "
            f"user_id={self.user_id}, role='{self.role.value}')>"
        )
