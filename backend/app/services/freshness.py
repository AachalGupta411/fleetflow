from datetime import datetime

LIVE_SECONDS = 45
RECENT_SECONDS = 180
STALE_SECONDS = 900


def classify_freshness(timestamp: datetime | None, now: datetime) -> str:
    """LIVE, RECENT, STALE, or OFFLINE. A missing fix is never described as live."""
    if timestamp is None:
        return "OFFLINE"
    age = (now - timestamp).total_seconds()
    if age < 0:
        return "LIVE"
    if age <= LIVE_SECONDS:
        return "LIVE"
    if age <= RECENT_SECONDS:
        return "RECENT"
    if age <= STALE_SECONDS:
        return "STALE"
    return "OFFLINE"
