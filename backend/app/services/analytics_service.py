from datetime import date
from decimal import Decimal

from sqlalchemy import DateTime, func, select
from sqlalchemy.orm import Session

from app.models.delivery import Delivery
from app.models.enums import ShipmentStatus
from app.models.fuel_record import FuelRecord
from app.models.vehicle import Vehicle
from app.schemas.operations import (
    BucketCost,
    BucketCount,
    DeliveryAnalytics,
    FailureReasonCount,
    FuelAnalytics,
    FuelVehicleBrief,
)
from app.services.metrics import money, outcome_rates, quantity
from app.services.operations_service import _average_duration, _count_active, list_driver_performance, utilization
from app.services.periods import bucket_name, resolve_range


def deliveries(db: Session, start: date | None, end: date | None, bucket: str) -> DeliveryAnalytics:
    start_day, end_day, start_at, end_at = resolve_range(start, end)
    grouping = bucket_name(bucket)
    period = func.date_trunc(grouping, Delivery.picked_up_at)
    rows = db.execute(
        select(period, func.count())
        .where(Delivery.picked_up_at.is_not(None), Delivery.picked_up_at >= start_at, Delivery.picked_up_at < end_at)
        .group_by(period)
        .order_by(period)
    ).all()
    completed = _status_count(db, ShipmentStatus.DELIVERED, Delivery.delivered_at, start_at, end_at)
    failed = _status_count(db, ShipmentStatus.FAILED, Delivery.failed_at, start_at, end_at)
    completion, _failure = outcome_rates(completed, failed)
    return DeliveryAnalytics(
        from_date=start_day,
        to_date=end_day,
        bucket=grouping,
        volume=[BucketCount(period=_period_label(item[0]), count=int(item[1])) for item in rows],
        completed=completed,
        failed=failed,
        active=_count_active(db),
        completion_rate=completion,
        average_delivery_duration_minutes=_average_duration(db, None, start_at, end_at),
    )


def drivers(db: Session, start: date | None, end: date | None):
    return list_driver_performance(db, start, end)


def fuel(db: Session, start: date | None, end: date | None) -> FuelAnalytics:
    start_day, end_day, start_at, end_at = resolve_range(start, end)
    period = func.date_trunc("day", func.cast(FuelRecord.fuel_date, DateTime(timezone=True)))
    totals = db.execute(
        select(
            func.coalesce(func.sum(FuelRecord.liters), 0),
            func.coalesce(func.sum(FuelRecord.total_cost), 0),
        ).where(FuelRecord.fuel_date >= start_day, FuelRecord.fuel_date <= end_day)
    ).one()
    liters = Decimal(totals[0])
    cost = Decimal(totals[1])
    average = None if liters == 0 else money((cost / liters).quantize(Decimal("0.01")))
    trend = db.execute(
        select(period, func.coalesce(func.sum(FuelRecord.total_cost), 0))
        .where(FuelRecord.fuel_date >= start_day, FuelRecord.fuel_date <= end_day)
        .group_by(period)
        .order_by(period)
    ).all()
    by_vehicle = db.execute(
        select(
            FuelRecord.vehicle_id,
            Vehicle.vehicle_number,
            func.coalesce(func.sum(FuelRecord.liters), 0),
            func.coalesce(func.sum(FuelRecord.total_cost), 0),
        )
        .join(Vehicle, Vehicle.id == FuelRecord.vehicle_id)
        .where(FuelRecord.fuel_date >= start_day, FuelRecord.fuel_date <= end_day)
        .group_by(FuelRecord.vehicle_id, Vehicle.vehicle_number)
        .order_by(func.sum(FuelRecord.total_cost).desc())
    ).all()
    return FuelAnalytics(
        from_date=start_day,
        to_date=end_day,
        total_liters=quantity(liters),
        total_cost=money(cost),
        average_price_per_liter=average,
        cost_trend=[BucketCost(period=_period_label(item[0]), total_cost=money(Decimal(item[1]))) for item in trend],
        by_vehicle=[
            FuelVehicleBrief(
                vehicle_id=item[0],
                vehicle_number=item[1],
                liters=quantity(Decimal(item[2])),
                total_cost=money(Decimal(item[3])),
            )
            for item in by_vehicle
        ],
    )


def failure_reasons(db: Session, start: date | None, end: date | None) -> list[FailureReasonCount]:
    _start_day, _end_day, start_at, end_at = resolve_range(start, end)
    rows = db.execute(
        select(Delivery.failure_code, func.count())
        .where(
            Delivery.status == ShipmentStatus.FAILED,
            Delivery.failure_code.is_not(None),
            Delivery.failed_at >= start_at,
            Delivery.failed_at < end_at,
        )
        .group_by(Delivery.failure_code)
        .order_by(func.count().desc())
    ).all()
    return [FailureReasonCount(reason=reason, count=int(count)) for reason, count in rows]


def fleet_utilization(db: Session):
    return utilization(db)


def _status_count(db, status, column, start_at, end_at) -> int:
    return int(
        db.scalar(
            select(func.count()).select_from(Delivery).where(
                Delivery.status == status,
                column >= start_at,
                column < end_at,
            )
        )
        or 0
    )


def _period_label(value) -> str:
    if hasattr(value, "date"):
        return value.date().isoformat()
    return str(value)
