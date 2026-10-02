import logging

from sqlalchemy import text
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def database_is_connected(db: Session) -> bool:
    """Return True only when PostgreSQL answers a real query."""
    try:
        db.execute(text("SELECT 1"))
        return True
    except Exception as exc:
        logger.warning("Database health check failed: %s", type(exc).__name__)
        return False
