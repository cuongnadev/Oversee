from collections.abc import Generator
from typing import Any

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import settings


def get_engine_kwargs(database_url: str) -> dict[str, Any]:
    """
    Construct SQLAlchemy engine configuration options based on dialect.

    - SQLite: Configures StaticPool and check_same_thread=False for testing/local file DB.
    - PostgreSQL: Configures connection pooling (size, max_overflow, pre-ping, recycle).
    """
    if database_url.startswith("sqlite"):
        return {
            "connect_args": {"check_same_thread": False},
            "poolclass": StaticPool,
        }
    return {
        "pool_size": 10,
        "max_overflow": 20,
        "pool_pre_ping": True,
        "pool_recycle": 3600,
    }


engine = create_engine(
    settings.database_url,
    **get_engine_kwargs(settings.database_url),
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
    expire_on_commit=False,
)


def get_db() -> Generator[Session]:
    """
    FastAPI dependency yielding a database session per request.
    Guarantees session closure upon request completion via try/finally block.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
