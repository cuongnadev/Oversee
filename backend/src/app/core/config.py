from functools import lru_cache
from typing import Literal
from urllib.parse import urlparse

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )

    app_name: str = "Oversee Backend"
    app_version: str = "0.1.0"
    environment: Literal["dev", "test", "prod"] = "dev"
    debug: bool = False
    host: str = "127.0.0.1"
    port: int = Field(default=8000, ge=1, le=65535)
    cors_origins: str = "*"
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"] = "INFO"
    secret_key: str = Field(min_length=32)
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = Field(default=15, ge=1)
    refresh_token_expire_days: int = Field(default=7, ge=1)
    database_url: str = Field(
        default="postgresql+psycopg://oversee:oversee_password@127.0.0.1:5432/oversee",
        description="Database connection URL",
    )

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @field_validator("secret_key")
    @classmethod
    def validate_secret_key(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("SECRET_KEY must not be blank")
        if len(value.strip()) < 32:
            raise ValueError("SECRET_KEY must be at least 32 characters")
        return value

    @field_validator("database_url")
    @classmethod
    def validate_database_url(cls, value: str) -> str:
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("DATABASE_URL must not be blank")
        valid_schemes = (
            "postgresql://",
            "postgresql+psycopg://",
            "postgresql+asyncpg://",
            "sqlite://",
            "sqlite+aiosqlite://",
        )
        if not any(trimmed.startswith(scheme) for scheme in valid_schemes):
            raise ValueError(
                "DATABASE_URL must start with a valid scheme "
                "(e.g. postgresql+psycopg://, postgresql://, or sqlite://)"
            )
        return trimmed

    @field_validator("cors_origins")
    @classmethod
    def validate_cors_origins(cls, value: str) -> str:
        origins = [o.strip() for o in value.split(",") if o.strip()]
        if len(origins) > 1 and "*" in origins:
            raise ValueError("Wildcard '*' cannot be combined with other origins")
        if value.strip() == "*":
            origins = ["*"]
        for origin in origins:
            if origin == "*":
                if len(origins) != 1:
                    raise ValueError("Wildcard '*' must be the only origin")
                continue
            parsed = urlparse(origin)
            if parsed.scheme not in ("http", "https"):
                raise ValueError(f"Invalid scheme for CORS origin: {origin}")
            if not parsed.hostname:
                raise ValueError(f"Missing hostname for CORS origin: {origin}")
            if parsed.username is not None or parsed.password is not None:
                raise ValueError(f"Credentials not allowed in CORS origin: {origin}")
            if parsed.path != "":
                raise ValueError(f"Path not allowed in CORS origin: {origin}")
            if parsed.query or parsed.fragment:
                raise ValueError(f"Query/fragment not allowed in CORS origin: {origin}")
            if parsed.port is not None and not (1 <= parsed.port <= 65535):
                raise ValueError(f"Invalid port for CORS origin: {origin}")
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
