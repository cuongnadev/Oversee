import logging
from typing import Any, Final

from fastapi import FastAPI, Request, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.config import settings

logger = logging.getLogger("oversee.error")

STATUS_CODE_MAP: Final[dict[int, str]] = {
    status.HTTP_400_BAD_REQUEST: "BAD_REQUEST",
    status.HTTP_401_UNAUTHORIZED: "UNAUTHORIZED",
    status.HTTP_403_FORBIDDEN: "FORBIDDEN",
    status.HTTP_404_NOT_FOUND: "NOT_FOUND",
    status.HTTP_405_METHOD_NOT_ALLOWED: "METHOD_NOT_ALLOWED",
    status.HTTP_409_CONFLICT: "CONFLICT",
    status.HTTP_422_UNPROCESSABLE_CONTENT: "UNPROCESSABLE_ENTITY",
    status.HTTP_429_TOO_MANY_REQUESTS: "TOO_MANY_REQUESTS",
    status.HTTP_500_INTERNAL_SERVER_ERROR: "INTERNAL_SERVER_ERROR",
    status.HTTP_502_BAD_GATEWAY: "BAD_GATEWAY",
    status.HTTP_503_SERVICE_UNAVAILABLE: "SERVICE_UNAVAILABLE",
    status.HTTP_504_GATEWAY_TIMEOUT: "GATEWAY_TIMEOUT",
}


class AppException(Exception):
    """
    Base application exception for standardized domain errors.
    """

    def __init__(
        self,
        status_code: int = status.HTTP_400_BAD_REQUEST,
        code: str | None = None,
        message: str = "An error occurred.",
        details: Any = None,
        headers: dict[str, str] | None = None,
    ) -> None:
        self.status_code = status_code
        self.code = code or STATUS_CODE_MAP.get(status_code, "ERROR")
        self.message = message
        self.details = details
        self.headers = headers
        super().__init__(message)


class BadRequestException(AppException):
    def __init__(
        self,
        message: str = "Bad request.",
        details: Any = None,
        code: str = "BAD_REQUEST",
    ) -> None:
        super().__init__(
            status_code=status.HTTP_400_BAD_REQUEST,
            code=code,
            message=message,
            details=details,
        )


class UnauthorizedException(AppException):
    def __init__(
        self,
        message: str = "Unauthorized.",
        details: Any = None,
        code: str = "UNAUTHORIZED",
        headers: dict[str, str] | None = None,
    ) -> None:
        super().__init__(
            status_code=status.HTTP_401_UNAUTHORIZED,
            code=code,
            message=message,
            details=details,
            headers=headers,
        )


class ForbiddenException(AppException):
    def __init__(
        self,
        message: str = "Forbidden.",
        details: Any = None,
        code: str = "FORBIDDEN",
    ) -> None:
        super().__init__(
            status_code=status.HTTP_403_FORBIDDEN,
            code=code,
            message=message,
            details=details,
        )


class NotFoundException(AppException):
    def __init__(
        self,
        message: str = "Resource not found.",
        details: Any = None,
        code: str = "NOT_FOUND",
    ) -> None:
        super().__init__(
            status_code=status.HTTP_404_NOT_FOUND,
            code=code,
            message=message,
            details=details,
        )


class ConflictException(AppException):
    def __init__(
        self,
        message: str = "Conflict occurred.",
        details: Any = None,
        code: str = "CONFLICT",
    ) -> None:
        super().__init__(
            status_code=status.HTTP_409_CONFLICT,
            code=code,
            message=message,
            details=details,
        )


class UnprocessableEntityException(AppException):
    def __init__(
        self,
        message: str = "Unprocessable entity.",
        details: Any = None,
        code: str = "UNPROCESSABLE_ENTITY",
    ) -> None:
        super().__init__(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            code=code,
            message=message,
            details=details,
        )


class InternalServerErrorException(AppException):
    def __init__(
        self,
        message: str = "Internal server error.",
        details: Any = None,
        code: str = "INTERNAL_SERVER_ERROR",
    ) -> None:
        super().__init__(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            code=code,
            message=message,
            details=details,
        )


def setup_exception_handlers(app: FastAPI) -> None:
    """
    Register global exception handlers on the FastAPI application instance.
    Standardizes error responses across all status codes (400, 401, 403, 404, 409, 422, 500).
    """

    @app.exception_handler(AppException)
    async def app_exception_handler(_: Request, exc: AppException) -> JSONResponse:
        content = {
            "code": exc.code,
            "message": exc.message,
            "details": exc.details,
            "detail": exc.message if exc.details is None else exc.details,
        }
        return JSONResponse(
            status_code=exc.status_code,
            content=content,
            headers=exc.headers,
        )

    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(
        _: Request, exc: StarletteHTTPException
    ) -> JSONResponse:
        default_code = STATUS_CODE_MAP.get(exc.status_code, "HTTP_ERROR")
        if isinstance(exc.detail, dict):
            code = exc.detail.get("code") or default_code
            message = (
                exc.detail.get("message")
                or exc.detail.get("detail")
                or "An error occurred."
            )
            details = exc.detail.get("details")
            detail = exc.detail.get("detail", message)
        elif isinstance(exc.detail, list):
            code = default_code
            message = "Validation error."
            details = exc.detail
            detail = exc.detail
        else:
            code = default_code
            message = (
                str(exc.detail) if exc.detail is not None else "An error occurred."
            )
            details = None
            detail = message

        content = {
            "code": code,
            "message": message,
            "details": details,
            "detail": detail,
        }
        return JSONResponse(
            status_code=exc.status_code,
            content=content,
            headers=exc.headers,
        )

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(
        _: Request, exc: RequestValidationError
    ) -> JSONResponse:
        clean_errors = jsonable_encoder(exc.errors())
        first_msg = (
            clean_errors[0].get("msg", "Validation error")
            if clean_errors
            else "Validation error."
        )
        first_loc = (
            ".".join(str(loc) for loc in clean_errors[0].get("loc", []))
            if clean_errors
            else ""
        )
        msg_prefix = f"{first_loc}: " if first_loc else ""
        content = {
            "code": "VALIDATION_ERROR",
            "message": f"Validation error: {msg_prefix}{first_msg}"
            if clean_errors
            else "Validation error.",
            "details": clean_errors,
            "detail": clean_errors,
        }
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            content=content,
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(
        request: Request, exc: Exception
    ) -> JSONResponse:
        logger.exception(
            "Unhandled server exception during %s %s: %s",
            request.method,
            request.url.path,
            exc,
        )
        content = {
            "code": "INTERNAL_SERVER_ERROR",
            "message": "An internal server error occurred. Please try again later.",
            "details": str(exc) if settings.debug else None,
            "detail": "An internal server error occurred. Please try again later.",
        }
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content=content,
        )
