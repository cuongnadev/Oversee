"""
Base declarative entity definitions, mixins, and naming conventions.

Conventions:
- Table names: plural, lowercase snake_case (e.g. `users`, `workspaces`, `projects`,
  `workspace_members`, `project_members`, `sprints`, `issues`).
- Column names: lowercase snake_case (e.g. `id`, `created_at`, `updated_at`, `deleted_at`).
- Primary keys: UUID v4 (`id`), constraint name `pk_<tablename>`.
- Foreign keys: `fk_<tablename>_<column>_<target_table>`.
- Unique constraints: `uq_<tablename>_<column>`.
- Indexes: `ix_<column_label>`.
- Check constraints: `ck_<tablename>_<constraint_name>`.
"""

import uuid
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import DateTime, MetaData, Uuid, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

# Standard naming conventions for constraints to ensure predictable names across PostgreSQL & Alembic
POSTGRES_NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    """SQLAlchemy 2.0 Declarative Base with naming conventions."""

    metadata = MetaData(naming_convention=POSTGRES_NAMING_CONVENTION)


class UUIDMixin:
    """Mixin that provides a UUID v4 primary key."""

    id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        sort_order=-100,
    )

    def __init__(self, **kwargs: Any) -> None:
        kwargs.setdefault("id", uuid.uuid4())
        super().__init__(**kwargs)


class TimestampMixin:
    """Mixin that provides timezone-aware audit timestamps (`created_at` and `updated_at`)."""

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=lambda: datetime.now(UTC),
        nullable=False,
        sort_order=100,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        default=lambda: datetime.now(UTC),
        onupdate=func.now(),
        nullable=False,
        sort_order=101,
    )

    def __init__(self, **kwargs: Any) -> None:
        now = datetime.now(UTC)
        kwargs.setdefault("created_at", now)
        kwargs.setdefault("updated_at", now)
        super().__init__(**kwargs)


class SoftDeleteMixin:
    """Mixin that provides soft delete capability via `deleted_at`."""

    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        default=None,
        sort_order=102,
    )

    @property
    def is_deleted(self) -> bool:
        """Returns True if the entity is marked as deleted."""
        return self.deleted_at is not None

    def soft_delete(self) -> None:
        """Mark the entity as soft-deleted with the current UTC timestamp."""
        self.deleted_at = datetime.now(UTC)

    def restore(self) -> None:
        """Restore the entity by clearing `deleted_at`."""
        self.deleted_at = None


class BaseEntity(UUIDMixin, TimestampMixin, SoftDeleteMixin, Base):
    """
    Abstract base entity for models that require UUID primary key,
    audit timestamps (`created_at`, `updated_at`), and soft delete support (`deleted_at`).
    """

    __abstract__ = True

    def __init__(self, **kwargs: Any) -> None:
        super().__init__(**kwargs)


class BaseAuditEntity(UUIDMixin, TimestampMixin, Base):
    """
    Abstract base entity for models that require UUID primary key and
    audit timestamps (`created_at`, `updated_at`) without soft delete.
    Typically used for membership, junction, or log tables.
    """

    __abstract__ = True

    def __init__(self, **kwargs: Any) -> None:
        super().__init__(**kwargs)
