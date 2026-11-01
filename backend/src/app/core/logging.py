import logging
import time

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

VALID_LEVELS = ("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")


def configure_logging(level: str = "INFO") -> None:
    normalized = level.upper()
    if normalized not in VALID_LEVELS:
        raise ValueError(f"Invalid log level: {level}")
    logging.basicConfig(
        level=getattr(logging, normalized),
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
        force=True,
    )


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        start = time.perf_counter()
        try:
            response = await call_next(request)
        except Exception:
            duration_ms = (time.perf_counter() - start) * 1000
            logging.getLogger("oversee.request").exception(
                "%s %s 500 %.2fms", request.method, request.url.path, duration_ms
            )
            raise
        duration_ms = (time.perf_counter() - start) * 1000
        logging.getLogger("oversee.request").info(
            "%s %s %s %.2fms",
            request.method,
            request.url.path,
            response.status_code,
            duration_ms,
        )
        return response
