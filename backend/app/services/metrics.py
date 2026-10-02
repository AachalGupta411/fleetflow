"""Operational calculations from recorded timestamps.

Delivery duration is delivered_at minus picked_up_at, in minutes.
It is calculated only when both timestamps exist and delivery is not before pickup.
Missing timestamps are not estimated. Failed deliveries are not included in this duration.
"""

from datetime import datetime
from decimal import Decimal


def delivery_duration_minutes(picked_up_at: datetime | None, delivered_at: datetime | None) -> float | None:
    if picked_up_at is None or delivered_at is None:
        return None
    seconds = (delivered_at - picked_up_at).total_seconds()
    if seconds < 0:
        return None
    return round(seconds / 60, 1)


def outcome_rates(completed: int, failed: int) -> tuple[float | None, float | None]:
    """Completion and failure rates over finished deliveries. None when there are none."""
    finished = completed + failed
    if finished == 0:
        return None, None
    return round(completed / finished, 4), round(failed / finished, 4)


def money(value: Decimal) -> str:
    return format(value.quantize(Decimal("0.01")), "f")


def quantity(value: Decimal) -> str:
    return format(value.quantize(Decimal("0.01")), "f")
