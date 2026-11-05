import os

import pytest


def pytest_configure(config):
    os.environ.setdefault("SECRET_KEY", "a" * 32)


@pytest.fixture(autouse=True)
def _isolate_settings_cache():
    from app.core.config import get_settings

    get_settings.cache_clear()
    yield
    get_settings.cache_clear()
