from datetime import date
from decimal import Decimal
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.models.driver import Driver
from app.models.fuel_record import FuelRecord
from app.models.user import User
from app.models.vehicle import Vehicle
from app.schemas.fuel import FUEL_TYPES, FuelCreate, FuelRead, FuelSummary, FuelVehicleTotal
from app.services.db_utils import commit
from app.services.notification_service import announce_operational

_MONEY = Decimal("0.01")


def list_fuel(
    db: Session,
    *,
    vehicle_id: UUID | None = None,
    driver_id: UUID | None = None,
    start: date | None = None,
    end: date | None = None,
) -> list[FuelRead]:
    statement = select(FuelRecord).order_by(FuelRecord.fuel_date.desc(), FuelRecord.created_at.desc())
    if vehicle_id is not None:
        statement = statement.where(FuelRecord.vehicle_id == vehicle_id)
    if driver_id is not None:
        statement = statement.where(FuelRecord.driver_id == driver_id)
    if start is not None:
        statement = statement.where(FuelRecord.fuel_date >= start)
    if end is not None:
        statement = statement.where(FuelRecord.fuel_date <= end)
    rows = db.scalars(statement.limit(200)).all()
    return [_to_read(db, row) for row in rows]


def get_fuel(db: Session, fuel_id: UUID) -> FuelRead:
    row = db.get(FuelRecord, fuel_id)
    if row is None:
        raise AppError(404, "Fuel record not found")
    return _to_read(db, row)


def create_fuel(db: Session, data: FuelCreate) -> FuelRead:
    vehicle = db.get(Vehicle, data.vehicle_id)
    if vehicle is None:
        raise AppError(404, "Vehicle not found")
    if data.driver_id is not None and db.get(Driver, data.driver_id) is None:
        raise AppError(404, "Driver not found")
    if data.odometer_km is not None and vehicle.current_odometer_km is not None:
        if data.odometer_km < vehicle.current_odometer_km:
            raise AppError(409, "Odometer cannot be lower than the current reading")
    total = (data.liters * data.price_per_liter).quantize(_MONEY)
    row = FuelRecord(
        vehicle_id=vehicle.id,
        driver_id=data.driver_id,
        liters=data.liters.quantize(_MONEY),
        price_per_liter=data.price_per_liter.quantize(_MONEY),
        total_cost=total,
        odometer_km=None if data.odometer_km is None else data.odometer_km.quantize(Decimal("0.1")),
        fuel_station=data.fuel_station.strip() if data.fuel_station else None,
        fuel_date=data.fuel_date,
        notes=data.notes.strip() if data.notes else None,
    )
    db.add(row)
    if row.odometer_km is not None:
        was_due = vehicle.service_status == "DUE"
        vehicle.current_odometer_km = row.odometer_km
        if vehicle.next_service_due_km is not None and row.odometer_km >= vehicle.next_service_due_km:
            vehicle.service_status = "DUE"
            if not was_due:
                announce_operational(
                    db,
                    kind="SERVICE_DUE",
                    title=f"Service due: {vehicle.vehicle_number} at {row.odometer_km} km",
                    body=f"{vehicle.vehicle_number} has reached its service distance.",
                )
        elif vehicle.service_status == "DUE" and (
            vehicle.next_service_due_km is None or row.odometer_km < vehicle.next_service_due_km
        ):
            vehicle.service_status = "OK"
    commit(db)
    db.refresh(row)
    return _to_read(db, row)


def summary(
    db: Session,
    *,
    vehicle_id: UUID | None = None,
    driver_id: UUID | None = None,
    start: date | None = None,
    end: date | None = None,
) -> FuelSummary:
    statement = select(
        func.coalesce(func.sum(FuelRecord.liters), 0),
        func.coalesce(func.sum(FuelRecord.total_cost), 0),
    )
    statement = _filter(statement, vehicle_id, driver_id, start, end)
    liters, cost = db.execute(statement).one()
    liters = Decimal(liters)
    cost = Decimal(cost)
    average = None if liters == 0 else (cost / liters).quantize(_MONEY)
    grouped = select(
        FuelRecord.vehicle_id,
        Vehicle.vehicle_number,
        func.coalesce(func.sum(FuelRecord.liters), 0),
        func.coalesce(func.sum(FuelRecord.total_cost), 0),
    ).join(Vehicle, Vehicle.id == FuelRecord.vehicle_id)
    grouped = _filter(grouped, vehicle_id, driver_id, start, end)
    grouped = grouped.group_by(FuelRecord.vehicle_id, Vehicle.vehicle_number).order_by(Vehicle.vehicle_number)
    by_vehicle = [
        FuelVehicleTotal(vehicle_id=item[0], vehicle_number=item[1], liters=Decimal(item[2]), total_cost=Decimal(item[3]))
        for item in db.execute(grouped).all()
    ]
    return FuelSummary(
        total_liters=liters,
        total_cost=cost,
        average_price_per_liter=average,
        by_vehicle=by_vehicle,
    )


def apply_vehicle_operations(
    vehicle: Vehicle,
    *,
    fuel_type: str | None = None,
    fuel_type_set: bool = False,
    fuel_efficiency_km_per_liter: Decimal | None = None,
    fuel_efficiency_set: bool = False,
    last_service_date: date | None = None,
    last_service_set: bool = False,
    next_service_due_km: Decimal | None = None,
    next_service_set: bool = False,
) -> None:
    if fuel_type_set:
        if fuel_type is None:
            vehicle.fuel_type = None
        else:
            cleaned = fuel_type.strip().upper()
            if cleaned not in FUEL_TYPES:
                raise AppError(400, "Fuel type must be PETROL, DIESEL, CNG, or ELECTRIC")
            vehicle.fuel_type = cleaned
    if fuel_efficiency_set:
        if fuel_efficiency_km_per_liter is not None and fuel_efficiency_km_per_liter <= 0:
            raise AppError(400, "Fuel efficiency must be positive")
        vehicle.fuel_efficiency_km_per_liter = fuel_efficiency_km_per_liter
    if last_service_set:
        vehicle.last_service_date = last_service_date
    if next_service_set:
        if next_service_due_km is not None and next_service_due_km < 0:
            raise AppError(400, "Service distance cannot be negative")
        vehicle.next_service_due_km = next_service_due_km
    _refresh_service_status(vehicle)


def _refresh_service_status(vehicle: Vehicle) -> None:
    if vehicle.next_service_due_km is None or vehicle.current_odometer_km is None:
        if vehicle.next_service_due_km is None:
            vehicle.service_status = "OK"
        return
    vehicle.service_status = "DUE" if vehicle.current_odometer_km >= vehicle.next_service_due_km else "OK"


def _filter(statement, vehicle_id, driver_id, start, end):
    if vehicle_id is not None:
        statement = statement.where(FuelRecord.vehicle_id == vehicle_id)
    if driver_id is not None:
        statement = statement.where(FuelRecord.driver_id == driver_id)
    if start is not None:
        statement = statement.where(FuelRecord.fuel_date >= start)
    if end is not None:
        statement = statement.where(FuelRecord.fuel_date <= end)
    return statement


def _to_read(db: Session, row: FuelRecord) -> FuelRead:
    vehicle = db.get(Vehicle, row.vehicle_id)
    driver_name = None
    if row.driver_id is not None:
        driver = db.get(Driver, row.driver_id)
        if driver is not None:
            user = db.get(User, driver.user_id)
            driver_name = None if user is None else user.name
    return FuelRead(
        id=row.id,
        vehicle_id=row.vehicle_id,
        vehicle_number="" if vehicle is None else vehicle.vehicle_number,
        driver_id=row.driver_id,
        driver_name=driver_name,
        liters=row.liters,
        price_per_liter=row.price_per_liter,
        total_cost=row.total_cost,
        odometer_km=row.odometer_km,
        fuel_station=row.fuel_station,
        fuel_date=row.fuel_date,
        notes=row.notes,
        created_at=row.created_at,
    )
