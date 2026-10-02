from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import require_roles
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.fuel import FuelCreate, FuelRead, FuelSummary
from app.services import fuel_service

router = APIRouter(prefix="/fuel", tags=["fuel"])
_managers = require_roles(UserRole.ADMIN, UserRole.FLEET_MANAGER)


@router.get("/summary", response_model=FuelSummary)
def fuel_summary(
    vehicle_id: UUID | None = None,
    driver_id: UUID | None = None,
    from_date: date | None = Query(default=None, alias="from"),
    to_date: date | None = Query(default=None, alias="to"),
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> FuelSummary:
    return fuel_service.summary(db, vehicle_id=vehicle_id, driver_id=driver_id, start=from_date, end=to_date)


@router.get("/vehicles/{vehicle_id}", response_model=list[FuelRead])
def fuel_for_vehicle(
    vehicle_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> list[FuelRead]:
    return fuel_service.list_fuel(db, vehicle_id=vehicle_id)


@router.get("", response_model=list[FuelRead])
def list_fuel(
    vehicle_id: UUID | None = None,
    driver_id: UUID | None = None,
    from_date: date | None = Query(default=None, alias="from"),
    to_date: date | None = Query(default=None, alias="to"),
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> list[FuelRead]:
    return fuel_service.list_fuel(db, vehicle_id=vehicle_id, driver_id=driver_id, start=from_date, end=to_date)


@router.post("", response_model=FuelRead, status_code=201)
def create_fuel(
    payload: FuelCreate,
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> FuelRead:
    return fuel_service.create_fuel(db, payload)


@router.get("/{fuel_id}", response_model=FuelRead)
def get_fuel(
    fuel_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> FuelRead:
    return fuel_service.get_fuel(db, fuel_id)
