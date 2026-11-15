from pydantic import BaseModel, ConfigDict, Field


class Token(BaseModel):
    """Schema returned upon successful authentication containing access and refresh tokens."""

    model_config = ConfigDict(extra="forbid")

    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenPayload(BaseModel):
    """Schema representing the decoded JWT payload."""

    model_config = ConfigDict(extra="ignore")

    sub: str | None = None
    type: str | None = None
    exp: int | None = None
    iat: int | None = None
    jti: str | None = None


class RefreshTokenRequest(BaseModel):
    """Schema for requesting a new token pair using a refresh token."""

    model_config = ConfigDict(extra="forbid")

    refresh_token: str = Field(min_length=1, description="The refresh token to rotate.")
