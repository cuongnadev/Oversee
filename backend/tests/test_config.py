import os

import pytest
from pydantic import ValidationError

from app.core.config import Settings, get_settings


def _make(**env):
    saved = {k: os.environ.get(k) for k in env}
    for k, v in env.items():
        os.environ[k] = v
    try:
        return Settings(_env_file=None)
    finally:
        for k in env:
            if saved[k] is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = saved[k]


def test_secret_valid():
    s = _make(SECRET_KEY="a" * 32)
    assert s.secret_key == "a" * 32


def test_secret_too_short():
    with pytest.raises(ValidationError):
        _make(SECRET_KEY="short")


def test_secret_blank():
    with pytest.raises(ValidationError):
        _make(SECRET_KEY=" " * 32)


def test_missing_secret_key():
    saved = os.environ.get("SECRET_KEY")
    os.environ.pop("SECRET_KEY", None)
    try:
        with pytest.raises(ValidationError) as exc:
            Settings(_env_file=None)
        assert "secret_key" in str(exc.value).lower()
    finally:
        if saved is None:
            os.environ.pop("SECRET_KEY", None)
        else:
            os.environ["SECRET_KEY"] = saved


def test_port_valid():
    s = _make(SECRET_KEY="a" * 32, PORT="8080")
    assert s.port == 8080


def test_port_minimum_valid():
    s = _make(SECRET_KEY="a" * 32, PORT="1")
    assert s.port == 1


def test_port_maximum_valid():
    s = _make(SECRET_KEY="a" * 32, PORT="65535")
    assert s.port == 65535


def test_port_zero():
    with pytest.raises(ValidationError):
        _make(SECRET_KEY="a" * 32, PORT="0")


def test_port_negative():
    with pytest.raises(ValidationError):
        _make(SECRET_KEY="a" * 32, PORT="-1")


def test_port_too_large():
    with pytest.raises(ValidationError):
        _make(SECRET_KEY="a" * 32, PORT="65536")


def test_cors_wildcard():
    s = _make(SECRET_KEY="a" * 32, CORS_ORIGINS="*")
    assert s.cors_origins_list == ["*"]


def test_cors_http_origin():
    s = _make(SECRET_KEY="a" * 32, CORS_ORIGINS="http://localhost:3000")
    assert s.cors_origins_list == ["http://localhost:3000"]


def test_cors_https_origin():
    s = _make(SECRET_KEY="a" * 32, CORS_ORIGINS="https://example.com")
    assert s.cors_origins_list == ["https://example.com"]


def test_cors_multiple_origins():
    s = _make(SECRET_KEY="a" * 32, CORS_ORIGINS="http://a.com, https://b.com")
    assert s.cors_origins_list == ["http://a.com", "https://b.com"]


def test_cors_ftp_rejected():
    with pytest.raises(ValidationError):
        _make(SECRET_KEY="a" * 32, CORS_ORIGINS="ftp://example.com")


def test_cors_path_rejected():
    with pytest.raises(ValidationError):
        _make(SECRET_KEY="a" * 32, CORS_ORIGINS="http://example.com/path")


def test_cors_query_rejected():
    with pytest.raises(ValidationError):
        _make(SECRET_KEY="a" * 32, CORS_ORIGINS="http://example.com?x=1")


def test_cors_fragment_rejected():
    with pytest.raises(ValidationError):
        _make(SECRET_KEY="a" * 32, CORS_ORIGINS="http://example.com#frag")


def test_cors_wildcard_combined_rejected():
    with pytest.raises(ValidationError):
        _make(SECRET_KEY="a" * 32, CORS_ORIGINS="*,http://example.com")


def test_cors_trailing_slash_rejected():
    with pytest.raises(ValidationError):
        _make(SECRET_KEY="a" * 32, CORS_ORIGINS="http://example.com/")


def test_cors_invalid_port_rejected():
    with pytest.raises(ValidationError):
        _make(SECRET_KEY="a" * 32, CORS_ORIGINS="http://example.com:99999")


def test_cors_credentials_rejected():
    with pytest.raises(ValidationError):
        _make(SECRET_KEY="a" * 32, CORS_ORIGINS="http://user:pass@example.com")


def test_default_values():
    s = _make(SECRET_KEY="a" * 32)
    assert s.app_name == "Oversee Backend"
    assert s.app_version == "0.1.0"
    assert s.environment == "dev"
    assert s.debug is False
    assert s.host == "127.0.0.1"
    assert s.port == 8000
    assert s.cors_origins == "*"


def test_override_env_var():
    s = _make(
        SECRET_KEY="b" * 32,
        APP_NAME="Custom App",
        APP_VERSION="2.0.0",
        ENVIRONMENT="prod",
        DEBUG="true",
        HOST="0.0.0.0",
        PORT="9000",
        CORS_ORIGINS="https://example.com",
    )
    assert s.app_name == "Custom App"
    assert s.app_version == "2.0.0"
    assert s.environment == "prod"
    assert s.debug is True
    assert s.host == "0.0.0.0"
    assert s.port == 9000
    assert s.cors_origins == "https://example.com"
    saved = os.environ.get("SECRET_KEY")
    os.environ["SECRET_KEY"] = "a" * 32
    try:
        assert get_settings() is get_settings()
    finally:
        if saved is None:
            os.environ.pop("SECRET_KEY", None)
        else:
            os.environ["SECRET_KEY"] = saved
        get_settings.cache_clear()
