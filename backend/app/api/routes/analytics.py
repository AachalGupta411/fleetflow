from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import require_roles
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.operations import (
    DeliveryAnalytics,
    DriverPerformance,
    FailureReasonCount,
    FleetUtilization,
    FuelAnalytics,
    OperationsOverview,
)
from app.services import analytics_service, operations_service

router = APIRouter(prefix="/analytics", tags=["analytics"])
_managers = require_roles(UserRole.ADMIN, UserRole.FLEET_MANAGER)


@router.get("/overview", response_model=OperationsOverview)
def overview(
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> OperationsOverview:
    return operations_service.overview(db)


@router.get("/deliveries", response_model=DeliveryAnalytics)
def deliveries(
    from_date: date | None = Query(default=None, alias="from"),
    to_date: date | None = Query(default=None, alias="to"),
    bucket: str = "day",
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> DeliveryAnalytics:
    return analytics_service.deliveries(db, from_date, to_date, bucket)


@router.get("/drivers", response_model=list[DriverPerformance])
def drivers(
    from_date: date | None = Query(default=None, alias="from"),
    to_date: date | None = Query(default=None, alias="to"),
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> list[DriverPerformance]:
    return analytics_service.drivers(db, from_date, to_date)


@router.get("/fuel", response_model=FuelAnalytics)
def fuel(
    from_date: date | None = Query(default=None, alias="from"),
    to_date: date | None = Query(default=None, alias="to"),
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> FuelAnalytics:
    return analytics_service.fuel(db, from_date, to_date)


@router.get("/failure-reasons", response_model=list[FailureReasonCount])
def failure_reasons(
    from_date: date | None = Query(default=None, alias="from"),
    to_date: date | None = Query(default=None, alias="to"),
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> list[FailureReasonCount]:
    return analytics_service.failure_reasons(db, from_date, to_date)


@router.get("/fleet-utilization", response_model=FleetUtilization)
def fleet_utilization(
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> FleetUtilization:
    return analytics_service.fleet_utilization(db)
