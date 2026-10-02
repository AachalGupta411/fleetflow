from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.errors import AppError
from app.models.driver import Driver
from app.models.enums import ACTIVE_SHIPMENT_STATUSES, VehicleStatus
from app.models.shipment import Shipment
from app.models.vehicle import Vehicle
from app.schemas.vehicle import VehicleCreate, VehicleRead, VehicleUpdate
from app.services import fuel_service
from app.services.db_utils import commit

MANUAL_VEHICLE_STATUSES = {
    VehicleStatus.AVAILABLE,
    VehicleStatus.IN_SERVICE,
    VehicleStatus.MAINTENANCE,
    VehicleStatus.INACTIVE,
}


def list_vehicles(db: Session) -> list[VehicleRead]:
    vehicles = db.scalars(
        select(Vehicle)
        .options(joinedload(Vehicle.driver).joinedload(Driver.user))
        .order_by(Vehicle.created_at.desc())
    ).all()
    return [_to_read(vehicle) for vehicle in vehicles]


def get_vehicle(db: Session, vehicle_id: UUID) -> VehicleRead:
    vehicle = _load(db, vehicle_id)
    if vehicle is None:
        raise AppError(404, "Vehicle not found")
    return _to_read(vehicle)


def create_vehicle(db: Session, data: VehicleCreate) -> VehicleRead:
    number = data.vehicle_number.strip().upper()
    if _number_taken(db, number):
        raise AppError(409, "Vehicle number is already in use")
    vehicle = Vehicle(
        vehicle_number=number,
        vehicle_type=data.vehicle_type.strip(),
        model=data.model.strip(),
        capacity=data.capacity,
        status=VehicleStatus.AVAILABLE,
    )
    db.add(vehicle)
    commit(db)
    created = _load(db, vehicle.id)
    return _to_read(created)


def update_vehicle(db: Session, vehicle_id: UUID, data: VehicleUpdate) -> VehicleRead:
    vehicle = _load(db, vehicle_id)
    if vehicle is None:
        raise AppError(404, "Vehicle not found")
    if data.vehicle_number is not None:
        number = data.vehicle_number.strip().upper()
        if _number_taken(db, number, ignore_id=vehicle.id):
            raise AppError(409, "Vehicle number is already in use")
        vehicle.vehicle_number = number
    if data.vehicle_type is not None:
        vehicle.vehicle_type = data.vehicle_type.strip()
    if data.model is not None:
        vehicle.model = data.model.strip()
    if data.capacity is not None:
        vehicle.capacity = data.capacity
    if data.status is not None and data.status != vehicle.status:
        if data.status == VehicleStatus.ASSIGNED:
            raise AppError(409, "Vehicle status changes to assigned only through shipment assignment")
        if data.status not in MANUAL_VEHICLE_STATUSES:
            raise AppError(409, "That vehicle status cannot be set directly")
        if _has_active_shipment(db, vehicle.id):
            raise AppError(409, "Vehicle still has an active shipment")
        vehicle.status = data.status
        if data.status != VehicleStatus.ASSIGNED:
            vehicle.driver_id = None
    fields = data.model_fields_set
    fuel_service.apply_vehicle_operations(
        vehicle,
        fuel_type=data.fuel_type,
        fuel_type_set="fuel_type" in fields,
        fuel_efficiency_km_per_liter=data.fuel_efficiency_km_per_liter,
        fuel_efficiency_set="fuel_efficiency_km_per_liter" in fields,
        last_service_date=data.last_service_date,
        last_service_set="last_service_date" in fields,
        next_service_due_km=data.next_service_due_km,
        next_service_set="next_service_due_km" in fields,
    )
    commit(db)
    refreshed = _load(db, vehicle.id)
    return _to_read(refreshed)


def _load(db: Session, vehicle_id: UUID) -> Vehicle | None:
    return db.scalar(
        select(Vehicle)
        .options(joinedload(Vehicle.driver).joinedload(Driver.user))
        .where(Vehicle.id == vehicle_id)
    )


def _number_taken(db: Session, vehicle_number: str, ignore_id: UUID | None = None) -> bool:
    statement = select(Vehicle.id).where(Vehicle.vehicle_number == vehicle_number)
    if ignore_id is not None:
        statement = statement.where(Vehicle.id != ignore_id)
    return db.scalar(statement) is not None


def _has_active_shipment(db: Session, vehicle_id: UUID) -> bool:
    return (
        db.scalar(
            select(Shipment.id).where(
                Shipment.assigned_vehicle_id == vehicle_id,
                Shipment.status.in_(ACTIVE_SHIPMENT_STATUSES),
            )
        )
        is not None
    )


def _to_read(vehicle: Vehicle) -> VehicleRead:
    driver_name = None
    if vehicle.driver is not None and vehicle.driver.user is not None:
        driver_name = vehicle.driver.user.name
    return VehicleRead(
        id=vehicle.id,
        vehicle_number=vehicle.vehicle_number,
        vehicle_type=vehicle.vehicle_type,
        model=vehicle.model,
        capacity=vehicle.capacity,
        status=vehicle.status,
        driver_id=vehicle.driver_id,
        driver_name=driver_name,
        fuel_type=vehicle.fuel_type,
        fuel_efficiency_km_per_liter=vehicle.fuel_efficiency_km_per_liter,
        current_odometer_km=vehicle.current_odometer_km,
        last_service_date=vehicle.last_service_date,
        next_service_due_km=vehicle.next_service_due_km,
        service_status=vehicle.service_status,
        created_at=vehicle.created_at,
        updated_at=vehicle.updated_at,
    )
