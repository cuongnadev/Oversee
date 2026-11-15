import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.v1.endpoints.health import health_ready
from app.db.session import get_db, get_engine_kwargs


def test_get_engine_kwargs_sqlite():
    kwargs = get_engine_kwargs("sqlite:///:memory:")
    assert kwargs["connect_args"] == {"check_same_thread": False}
    assert kwargs["poolclass"] is StaticPool


def test_get_engine_kwargs_postgresql():
    kwargs = get_engine_kwargs("postgresql+psycopg://user:pass@127.0.0.1:5432/oversee")
    assert kwargs["pool_size"] == 10
    assert kwargs["max_overflow"] == 20
    assert kwargs["pool_pre_ping"] is True
    assert kwargs["pool_recycle"] == 3600


def test_get_db_lifecycle(monkeypatch):
    """Verify that get_db yields an active session and closes it upon exit."""
    test_engine = create_engine("sqlite:///:memory:")
    test_session_local = sessionmaker(
        autocommit=False,
        autoflush=False,
        bind=test_engine,
    )
    monkeypatch.setattr("app.db.session.SessionLocal", test_session_local)

    gen = get_db()
    session = next(gen)

    assert isinstance(session, Session)
    result = session.execute(text("SELECT 1")).scalar()
    assert result == 1

    closed = False
    original_close = session.close

    def spy_close():
        nonlocal closed
        closed = True
        original_close()

    session.close = spy_close

    # End the generator, which triggers the finally block
    with pytest.raises(StopIteration):
        next(gen)

    # Verify session.close() was invoked
    assert closed is True


def test_health_ready_endpoint_direct():
    """Verify that health_ready endpoint queries the DB session via Depends(get_db)."""
    test_engine = create_engine("sqlite:///:memory:")
    test_session = sessionmaker(bind=test_engine)()
    try:
        response = health_ready(db=test_session)
        assert response == {"status": "ready", "database": "connected"}
    finally:
        test_session.close()
