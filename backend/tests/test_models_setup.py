import uuid

from sqlalchemy import ForeignKey, String, create_engine
from sqlalchemy.orm import Mapped, mapped_column

import app.models as models_pkg
from app.models import (
    POSTGRES_NAMING_CONVENTION,
    Base,
    BaseEntity,
)


def test_models_package_exports():
    """Verify that app.models exports all required base classes and metadata."""
    expected_exports = [
        "Base",
        "BaseEntity",
        "BaseAuditEntity",
        "UUIDMixin",
        "TimestampMixin",
        "SoftDeleteMixin",
        "POSTGRES_NAMING_CONVENTION",
    ]
    for symbol in expected_exports:
        assert hasattr(models_pkg, symbol), f"Missing export {symbol} in app.models"


def test_declarative_base_metadata():
    """Verify that Base has a valid MetaData object configured with conventions."""
    assert Base.metadata is not None
    assert Base.metadata.naming_convention == POSTGRES_NAMING_CONVENTION


def test_constraint_naming_conventions_applied():
    """
    Verify that table creation automatically applies naming conventions
    to Primary Key, Unique Constraint, and Foreign Key.
    """

    class ExampleParent(BaseEntity):
        __tablename__ = "example_parents"

        code: Mapped[str] = mapped_column(String(20), unique=True)

    class ExampleChild(BaseEntity):
        __tablename__ = "example_children"

        parent_id: Mapped[uuid.UUID] = mapped_column(
            ForeignKey("example_parents.id"),
            nullable=False,
        )

    # In-memory SQLite engine to test metadata creation
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(
        engine,
        tables=[ExampleParent.__table__, ExampleChild.__table__],
    )

    try:
        # Check Primary Key constraint names
        assert ExampleParent.__table__.primary_key.name == "pk_example_parents"
        assert ExampleChild.__table__.primary_key.name == "pk_example_children"

        # Check Foreign Key constraint name
        fk_constraint = next(iter(ExampleChild.__table__.foreign_key_constraints))
        assert fk_constraint.name == "fk_example_children_parent_id_example_parents"

        # Check Unique constraint on parent code
        uq_names = [
            c.name for c in ExampleParent.__table__.constraints if hasattr(c, "columns")
        ]
        assert "uq_example_parents_code" in uq_names or any(
            name and "uq_example_parents" in name for name in uq_names
        )
    finally:
        Base.metadata.drop_all(
            engine,
            tables=[ExampleChild.__table__, ExampleParent.__table__],
        )
        Base.metadata.remove(ExampleChild.__table__)
        Base.metadata.remove(ExampleParent.__table__)
