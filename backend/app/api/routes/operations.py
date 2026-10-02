from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import require_roles
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.operations import (
    DriverOperations,
    DriverPerformance,
    FleetUtilization,
    FleetVehicle,
    OperationsOverview,
    VehicleOperations,
)
from app.services import operations_service

router = APIRouter(prefix="/operations", tags=["operations"])
_managers = require_roles(UserRole.ADMIN, UserRole.FLEET_MANAGER)


@router.get("/overview", response_model=OperationsOverview)
def overview(
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> OperationsOverview:
    return operations_service.overview(db)


@router.get("/fleet", response_model=list[FleetVehicle])
def fleet(
    status: str | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> list[FleetVehicle]:
    return operations_service.fleet_board(db, status)


@router.get("/vehicles/{vehicle_id}", response_model=VehicleOperations)
def vehicle(
    vehicle_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> VehicleOperations:
    return operations_service.vehicle_detail(db, vehicle_id)


@router.get("/drivers", response_model=list[DriverPerformance])
def drivers(
    from_date: date | None = Query(default=None, alias="from"),
    to_date: date | None = Query(default=None, alias="to"),
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> list[DriverPerformance]:
    return operations_service.list_driver_performance(db, from_date, to_date)


@router.get("/drivers/{driver_id}", response_model=DriverOperations)
def driver(
    driver_id: UUID,
    from_date: date | None = Query(default=None, alias="from"),
    to_date: date | None = Query(default=None, alias="to"),
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> DriverOperations:
    return operations_service.driver_detail(db, driver_id, from_date, to_date)


@router.get("/drivers/{driver_id}/performance", response_model=DriverPerformance)
def driver_performance(
    driver_id: UUID,
    from_date: date | None = Query(default=None, alias="from"),
    to_date: date | None = Query(default=None, alias="to"),
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> DriverPerformance:
    return operations_service.driver_performance(db, driver_id, from_date, to_date)


@router.get("/utilization", response_model=FleetUtilization)
def utilization(
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> FleetUtilization:
    return operations_service.utilization(db)
