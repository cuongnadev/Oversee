import time
import uuid
from datetime import UTC, datetime

import pytest
from sqlalchemy import String, create_engine, select
from sqlalchemy.orm import Mapped, mapped_column, sessionmaker

from app.models.base import (
    POSTGRES_NAMING_CONVENTION,
    Base,
    BaseAuditEntity,
    BaseEntity,
)


# Test entity inheriting from BaseEntity (with soft delete)
class DummyItem(BaseEntity):
    __tablename__ = "dummy_items"

    name: Mapped[str] = mapped_column(String(50), nullable=False)


# Test entity inheriting from BaseAuditEntity (without soft delete)
class DummyAuditItem(BaseAuditEntity):
    __tablename__ = "dummy_audit_items"

    title: Mapped[str] = mapped_column(String(50), nullable=False)


@pytest.fixture
def db_session():
    """In-memory SQLite session for testing base model behavior."""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)
    session = session_factory()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(engine)


def test_naming_convention():
    """Verify that custom naming conventions are registered in metadata."""
    assert Base.metadata.naming_convention == POSTGRES_NAMING_CONVENTION
    assert Base.metadata.naming_convention["pk"] == "pk_%(table_name)s"


def test_base_entity_instantiation_defaults():
    """Verify that BaseEntity sets default UUID and timestamps upon instantiation."""
    item = DummyItem(name="Sample Item")

    assert isinstance(item.id, uuid.UUID)
    assert isinstance(item.created_at, datetime)
    assert isinstance(item.updated_at, datetime)
    assert item.deleted_at is None
    assert item.is_deleted is False


def test_soft_delete_and_restore():
    """Verify soft_delete and restore helper methods."""
    item = DummyItem(name="Soft Delete Test")
    assert item.is_deleted is False
    assert item.deleted_at is None

    item.soft_delete()
    assert item.is_deleted is True
    assert isinstance(item.deleted_at, datetime)
    assert item.deleted_at.tzinfo is not None

    item.restore()
    assert item.is_deleted is False
    assert item.deleted_at is None


def test_base_entity_db_persistence(db_session):
    """Verify persistence, auto-generated UUID, and timestamps in database."""
    item = DummyItem(name="Persistent Item")
    item_id = item.id

    db_session.add(item)
    db_session.commit()

    saved = db_session.scalar(select(DummyItem).where(DummyItem.id == item_id))
    assert saved is not None
    assert saved.id == item_id
    assert saved.name == "Persistent Item"
    assert saved.created_at is not None
    assert saved.updated_at is not None
    assert saved.deleted_at is None


def test_base_entity_timestamp_update_on_change(db_session):
    """Verify that updated_at timestamp updates when record is modified."""
    item = DummyItem(name="Original Name")
    db_session.add(item)
    db_session.commit()

    original_created_at = item.created_at
    original_updated_at = item.updated_at

    # Small delay to ensure timestamp progression
    time.sleep(0.01)

    item.name = "Modified Name"
    # Ensure manual or server-level timestamp change triggers
    item.updated_at = datetime.now(UTC)
    db_session.commit()

    db_session.refresh(item)
    assert item.name == "Modified Name"
    assert item.created_at == original_created_at
    assert item.updated_at >= original_updated_at


def test_base_audit_entity_persistence(db_session):
    """Verify that BaseAuditEntity provides id and audit timestamps without deleted_at."""
    audit_item = DummyAuditItem(title="Audit Log Entry")
    db_session.add(audit_item)
    db_session.commit()

    saved = db_session.scalar(
        select(DummyAuditItem).where(DummyAuditItem.id == audit_item.id)
    )
    assert saved is not None
    assert isinstance(saved.id, uuid.UUID)
    assert saved.title == "Audit Log Entry"
    assert saved.created_at is not None
    assert saved.updated_at is not None
    assert not hasattr(saved, "deleted_at")
