import uuid

import pytest
from pydantic import ValidationError
from sqlalchemy import create_engine, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

from app.models.base import Base
from app.models.user import User
from app.schemas.user import UserCreate, UserResponse, UserUpdate


@pytest.fixture
def db_session():
    """In-memory SQLite session for testing User model."""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine, tables=[User.__table__])
    session_factory = sessionmaker(bind=engine)
    session = session_factory()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(engine, tables=[User.__table__])


def test_user_creation_and_query(db_session):
    """Test creating and retrieving a User record."""
    user = User(
        email="developer@example.com",
        hashed_password="hashed_secure_password_123",
        full_name="Oversee Developer",
        avatar_url="https://example.com/avatar.png",
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()

    # Query by ID
    fetched_by_id = db_session.scalar(select(User).where(User.id == user.id))
    assert fetched_by_id is not None
    assert fetched_by_id.email == "developer@example.com"
    assert fetched_by_id.full_name == "Oversee Developer"
    assert fetched_by_id.avatar_url == "https://example.com/avatar.png"
    assert fetched_by_id.is_active is True
    assert isinstance(fetched_by_id.id, uuid.UUID)
    assert fetched_by_id.created_at is not None
    assert fetched_by_id.updated_at is not None
    assert fetched_by_id.deleted_at is None

    # Query by Email
    fetched_by_email = db_session.scalar(
        select(User).where(User.email == "developer@example.com")
    )
    assert fetched_by_email is not None
    assert fetched_by_email.id == user.id


def test_user_email_unique_constraint(db_session):
    """Test that duplicate email addresses raise an IntegrityError."""
    user1 = User(
        email="unique@example.com",
        hashed_password="hash1",
        full_name="User One",
    )
    db_session.add(user1)
    db_session.commit()

    user2 = User(
        email="unique@example.com",
        hashed_password="hash2",
        full_name="User Two",
    )
    db_session.add(user2)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


def test_user_email_index():
    """Verify that an index is configured for the email column."""
    index_names = [idx.name for idx in User.__table__.indexes]
    assert any("email" in (name or "") for name in index_names)


def test_user_soft_delete(db_session):
    """Test soft delete and restore lifecycle for User."""
    user = User(
        email="softdelete@example.com",
        hashed_password="hash",
        full_name="Soft Delete User",
    )
    db_session.add(user)
    db_session.commit()

    assert user.is_deleted is False
    assert user.deleted_at is None

    user.soft_delete()
    db_session.commit()

    assert user.is_deleted is True
    assert user.deleted_at is not None

    user.restore()
    db_session.commit()

    assert user.is_deleted is False
    assert user.deleted_at is None


def test_user_pydantic_schemas():
    """Test User Pydantic schema validation and serialization."""
    # Valid UserCreate
    create_dto = UserCreate(
        email="schema_test@example.com",
        full_name="Schema Tester",
        password="securepassword123",
    )
    assert create_dto.email == "schema_test@example.com"
    assert create_dto.password == "securepassword123"

    # Invalid email
    with pytest.raises(ValidationError):
        UserCreate(
            email="invalid-email",
            full_name="Tester",
            password="securepassword123",
        )

    # Short password
    with pytest.raises(ValidationError):
        UserCreate(
            email="valid@example.com",
            full_name="Tester",
            password="short",
        )

    # Valid UserUpdate
    update_dto = UserUpdate(full_name="Updated Name")
    assert update_dto.full_name == "Updated Name"
    assert update_dto.email is None

    # Conversion to UserResponse from SQLAlchemy model
    user_model = User(
        email="response_test@example.com",
        hashed_password="hash",
        full_name="Response User",
    )
    response_dto = UserResponse.model_validate(user_model)
    assert response_dto.id == user_model.id
    assert response_dto.email == user_model.email
    assert response_dto.full_name == user_model.full_name
    assert not hasattr(response_dto, "hashed_password")
