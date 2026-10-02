from datetime import UTC, date, datetime, time, timedelta

from app.core.errors import AppError


def resolve_range(start: date | None, end: date | None) -> tuple[date, date, datetime, datetime]:
    """Inclusive calendar dates. Both ends are required together. Default is the last 30 days."""
    today = datetime.now(UTC).date()
    if start is None and end is None:
        start = today - timedelta(days=29)
        end = today
    elif start is None or end is None:
        raise AppError(400, "Provide both from and to, or neither")
    if start > end:
        raise AppError(400, "from must be on or before to")
    if (end - start).days > 366:
        raise AppError(400, "Date range cannot exceed 366 days")
    start_at = datetime.combine(start, time.min, tzinfo=UTC)
    end_at = datetime.combine(end + timedelta(days=1), time.min, tzinfo=UTC)
    return start, end, start_at, end_at


def bucket_name(value: str) -> str:
    if value not in {"day", "week"}:
        raise AppError(400, "bucket must be day or week")
    return value
