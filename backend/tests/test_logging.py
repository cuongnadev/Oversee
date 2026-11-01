import logging

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.core.logging import RequestLoggingMiddleware, configure_logging


def test_configure_logging_valid_levels():
    for level in ("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"):
        configure_logging(level)
        assert logging.getLogger().level == getattr(logging, level)


def test_configure_logging_invalid_level():
    with pytest.raises(ValueError):
        configure_logging("INVALID")


def test_logging_format(capsys):
    configure_logging("INFO")
    logger = logging.getLogger("test.format")
    logger.info("hello")
    captured = capsys.readouterr()
    assert " | " in captured.err or " | " in captured.out


def test_middleware_success(caplog):
    app = FastAPI()
    app.add_middleware(RequestLoggingMiddleware)

    @app.get("/ok")
    def ok():
        return {"ok": True}

    client = TestClient(app)
    with caplog.at_level(logging.INFO, logger="oversee.request"):
        resp = client.get("/ok")
    assert resp.status_code == 200
    assert "GET /ok 200" in caplog.text


def test_middleware_http_error(caplog):
    app = FastAPI()
    app.add_middleware(RequestLoggingMiddleware)

    @app.get("/bad")
    def bad():
        raise HTTPException(status_code=404, detail="not found")

    client = TestClient(app)
    with caplog.at_level(logging.INFO, logger="oversee.request"):
        resp = client.get("/bad")
    assert resp.status_code == 404
    assert "GET /bad 404" in caplog.text


def test_middleware_exception(caplog):
    app = FastAPI()
    app.add_middleware(RequestLoggingMiddleware)

    @app.get("/boom")
    def boom():
        raise RuntimeError("boom")

    client = TestClient(app)
    with (
        caplog.at_level(logging.INFO, logger="oversee.request"),
        pytest.raises(RuntimeError),
    ):
        client.get("/boom")
    assert "GET /boom 500" in caplog.text


def test_no_sensitive_data(caplog):
    app = FastAPI()
    app.add_middleware(RequestLoggingMiddleware)

    @app.get("/secret")
    def secret():
        return {"token": "supersecret", "password": "p@ss"}

    client = TestClient(app)
    with caplog.at_level(logging.INFO, logger="oversee.request"):
        client.get("/secret?token=abc&password=xyz")
    oversee_records = [r for r in caplog.records if r.name == "oversee.request"]
    combined = " ".join(r.getMessage() for r in oversee_records)
    assert "supersecret" not in combined
    assert "p@ss" not in combined
    assert "abc" not in combined
    assert "xyz" not in combined
