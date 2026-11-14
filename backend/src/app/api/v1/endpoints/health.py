from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db.session import get_db

router = APIRouter()


@router.get("", tags=["health"])
def health():
    return {"status": "ok", "version": "0.1.0"}


@router.get("/ready", tags=["health"])
def health_ready(db: Annotated[Session, Depends(get_db)]):
    """Check database connectivity and service readiness."""
    db.execute(text("SELECT 1"))
    return {"status": "ready", "database": "connected"}
