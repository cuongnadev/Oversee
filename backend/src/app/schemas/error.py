from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class ErrorResponse(BaseModel):
    """
    Standardized API Error Response Schema (#112).
    Every API error response follows this structure:
      - code: Machine-readable error code (e.g. BAD_REQUEST, NOT_FOUND, VALIDATION_ERROR)
      - message: Human-readable error message summary
      - details: Additional contextual information or validation errors list
      - detail: Backward-compatible alias for detail
    """

    model_config = ConfigDict(extra="ignore")

    code: str = Field(
        ...,
        description="Machine-readable error code (e.g. BAD_REQUEST, NOT_FOUND, VALIDATION_ERROR)",
    )
    message: str = Field(
        ...,
        description="Human-readable error summary",
    )
    details: Any = Field(
        default=None,
        description="Detailed contextual information or validation errors list",
    )
    detail: Any = Field(
        default=None,
        description="Backward-compatible alias for detail",
    )
