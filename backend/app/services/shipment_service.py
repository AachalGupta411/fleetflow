from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.errors import AppError
from app.models.delivery import Delivery
from app.models.driver import Driver
from app.models.enums import (
    ACTIVE_SHIPMENT_STATUSES,
    DriverStatus,
    ShipmentStatus,
    UserRole,
    VehicleStatus,
)
from app.models.shipment import Shipment
from app.models.user import User
from app.models.vehicle import Vehicle
from app.schemas.shipment import (
    AssignmentRequest,
    ShipmentCreate,
    ShipmentRead,
    ShipmentUpdate,
    StatusUpdateRequest,
)
from app.services.db_utils import commit
from app.services.delivery_events import add_event
from app.services.notification_service import announce, staff_ids

_OPERATIONAL_TRANSITIONS: dict[ShipmentStatus, set[ShipmentStatus]] = {
    ShipmentStatus.PENDING: {ShipmentStatus.CANCELLED},
    ShipmentStatus.ASSIGNED: {ShipmentStatus.PICKED_UP, ShipmentStatus.CANCELLED},
    ShipmentStatus.PICKED_UP: {ShipmentStatus.IN_TRANSIT},
    ShipmentStatus.IN_TRANSIT: {ShipmentStatus.ARRIVING, ShipmentStatus.FAILED},
    ShipmentStatus.ARRIVING: {ShipmentStatus.FAILED},
    ShipmentStatus.DELIVERED: set(),
    ShipmentStatus.FAILED: set(),
    ShipmentStatus.CANCELLED: set(),
}

_TERMINAL = {ShipmentStatus.DELIVERED, ShipmentStatus.FAILED, ShipmentStatus.CANCELLED}


def list_shipments(db: Session, actor: User) -> list[ShipmentRead]:
    statement = _shipment_query().order_by(Shipment.created_at.desc())
    if actor.role == UserRole.CUSTOMER:
        statement = statement.where(Shipment.customer_id == actor.id)
    elif actor.role == UserRole.DRIVER:
        driver_id = _driver_id_for_user(db, actor)
        statement = statement.where(Shipment.assigned_driver_id == driver_id)
    elif actor.role not in {UserRole.ADMIN, UserRole.FLEET_MANAGER}:
        raise AppError(403, "You do not have access to this resource")
    shipments = db.scalars(statement.limit(200)).unique().all()
    return [_to_read(shipment) for shipment in shipments]


def list_driver_shipments(db: Session, actor: User) -> list[ShipmentRead]:
    if actor.role != UserRole.DRIVER:
        raise AppError(403, "You do not have access to this resource")
    return list_shipments(db, actor)


def get_shipment(db: Session, actor: User, shipment_id: UUID) -> ShipmentRead:
    shipment = _visible_shipment(db, actor, shipment_id)
    return _to_read(shipment)


def create_shipment(db: Session, actor: User, data: ShipmentCreate) -> ShipmentRead:
    if actor.role != UserRole.CUSTOMER:
        raise AppError(403, "Only customers can create shipments")
    shipment = Shipment(
        tracking_number=_next_tracking_number(db),
        customer_id=actor.id,
        pickup_address=data.pickup_address.strip(),
        delivery_address=data.delivery_address.strip(),
        package_description=data.package_description.strip(),
        priority=data.priority,
        status=ShipmentStatus.PENDING,
    )
    db.add(shipment)
    db.flush()
    db.add(Delivery(shipment_id=shipment.id, status=ShipmentStatus.PENDING))
    commit(db)
    return _to_read(_require_loaded(db, shipment.id))


def update_shipment(db: Session, actor: User, shipment_id: UUID, data: ShipmentUpdate) -> ShipmentRead:
    shipment = _visible_shipment(db, actor, shipment_id)
    if actor.role != UserRole.CUSTOMER or shipment.customer_id != actor.id:
        raise AppError(403, "You do not have access to this resource")
    if shipment.status != ShipmentStatus.PENDING:
        raise AppError(409, "Only pending shipments can be edited")
    if data.pickup_address is not None:
        shipment.pickup_address = data.pickup_address.strip()
    if data.delivery_address is not None:
        shipment.delivery_address = data.delivery_address.strip()
    if data.package_description is not None:
        shipment.package_description = data.package_description.strip()
    if data.priority is not None:
        shipment.priority = data.priority
    commit(db)
    return _to_read(_require_loaded(db, shipment.id))


def assign_shipment(db: Session, shipment_id: UUID, data: AssignmentRequest) -> ShipmentRead:
    shipment = db.scalar(select(Shipment).where(Shipment.id == shipment_id).with_for_update())
    if shipment is None:
        raise AppError(404, "Shipment not found")
    if shipment.status != ShipmentStatus.PENDING:
        raise AppError(409, "Shipment cannot be assigned in its current status")

    driver = db.scalar(select(Driver).where(Driver.id == data.driver_id).with_for_update())
    if driver is None:
        raise AppError(404, "Driver not found")
    if driver.status != DriverStatus.AVAILABLE or not driver.user.is_active:
        raise AppError(409, "Driver is not available for assignment")

    vehicle = db.scalar(select(Vehicle).where(Vehicle.id == data.vehicle_id).with_for_update())
    if vehicle is None:
        raise AppError(404, "Vehicle not found")
    if vehicle.status != VehicleStatus.AVAILABLE:
        raise AppError(409, "Vehicle is not available for assignment")

    shipment.status = ShipmentStatus.ASSIGNED
    shipment.assigned_driver_id = driver.id
    shipment.assigned_vehicle_id = vehicle.id
    driver.status = DriverStatus.ON_DELIVERY
    vehicle.status = VehicleStatus.ASSIGNED
    vehicle.driver_id = driver.id

    delivery = shipment.delivery or db.scalar(select(Delivery).where(Delivery.shipment_id == shipment.id))
    if delivery is None:
        delivery = Delivery(shipment_id=shipment.id)
        db.add(delivery)
    delivery.driver_id = driver.id
    delivery.vehicle_id = vehicle.id
    delivery.status = ShipmentStatus.ASSIGNED
    add_event(db, delivery_id=delivery.id, event_type="ASSIGNED", actor_user_id=None)
    announce(
        db,
        kind="SHIPMENT_ASSIGNED",
        shipment=shipment,
        title="Shipment assigned",
        body=f"{shipment.tracking_number} has been assigned for delivery.",
        user_ids=[shipment.customer_id, driver.user_id],
    )
    commit(db)
    return _to_read(_require_loaded(db, shipment.id))


def update_status(db: Session, actor: User, shipment_id: UUID, data: StatusUpdateRequest) -> ShipmentRead:
    shipment = _visible_shipment(db, actor, shipment_id)
    new_status = data.status
    if new_status == ShipmentStatus.DELIVERED:
        raise AppError(409, "Complete proof of delivery before marking the shipment delivered")
    if new_status == ShipmentStatus.ASSIGNED:
        raise AppError(409, "Assign a driver and vehicle to move a shipment to assigned")
    if new_status not in _OPERATIONAL_TRANSITIONS[shipment.status]:
        raise AppError(409, "That status change is not allowed")
    _assert_actor_can_change(actor, shipment, new_status)
    if new_status == ShipmentStatus.FAILED and not (data.failure_reason and data.failure_reason.strip()):
        raise AppError(422, "A failure reason is required")

    now = datetime.now(UTC)
    shipment.status = new_status
    delivery = shipment.delivery
    if delivery is None:
        delivery = Delivery(shipment_id=shipment.id)
        db.add(delivery)
    delivery.status = new_status
    if new_status == ShipmentStatus.PICKED_UP and delivery.started_at is None:
        delivery.started_at = now
        delivery.picked_up_at = now
    if new_status in _TERMINAL:
        delivery.completed_at = now
    if new_status == ShipmentStatus.FAILED:
        delivery.failure_reason = data.failure_reason.strip()
        delivery.failed_at = now
    add_event(
        db,
        delivery_id=delivery.id,
        event_type=new_status.value,
        actor_user_id=actor.id,
        note=delivery.failure_reason,
    )
    if new_status == ShipmentStatus.PICKED_UP:
        announce(
            db,
            kind="SHIPMENT_PICKED_UP",
            shipment=shipment,
            title="Shipment picked up",
            body=f"{shipment.tracking_number} has been picked up.",
            user_ids=[shipment.customer_id],
        )
    if new_status == ShipmentStatus.FAILED:
        announce(
            db,
            kind="DELIVERY_FAILED",
            shipment=shipment,
            title="Delivery failed",
            body=f"{shipment.tracking_number} could not be delivered.",
            user_ids=[shipment.customer_id, *staff_ids(db)],
        )
    if new_status not in ACTIVE_SHIPMENT_STATUSES:
        _release_resources(db, shipment)
    commit(db)
    return _to_read(_require_loaded(db, shipment.id))


def _assert_actor_can_change(actor: User, shipment: Shipment, new_status: ShipmentStatus) -> None:
    if new_status == ShipmentStatus.CANCELLED:
        if actor.role == UserRole.CUSTOMER and shipment.customer_id == actor.id:
            if shipment.status != ShipmentStatus.PENDING:
                raise AppError(409, "That status change is not allowed")
            return
        if actor.role in {UserRole.ADMIN, UserRole.FLEET_MANAGER}:
            return
        raise AppError(403, "You do not have access to this resource")
    if actor.role == UserRole.DRIVER:
        driver = shipment.assigned_driver
        if driver is None or driver.user_id != actor.id:
            raise AppError(404, "Shipment not found")
        return
    if actor.role not in {UserRole.ADMIN, UserRole.FLEET_MANAGER}:
        raise AppError(403, "You do not have access to this resource")


def release_assignment(db: Session, shipment: Shipment) -> None:
    _release_resources(db, shipment)


def _release_resources(db: Session, shipment: Shipment) -> None:
    if shipment.assigned_driver_id is not None and not _driver_has_other_active(
        db, shipment.assigned_driver_id, shipment.id
    ):
        driver = db.get(Driver, shipment.assigned_driver_id)
        if driver is not None and driver.status == DriverStatus.ON_DELIVERY:
            driver.status = DriverStatus.AVAILABLE
    if shipment.assigned_vehicle_id is not None and not _vehicle_has_other_active(
        db, shipment.assigned_vehicle_id, shipment.id
    ):
        vehicle = db.get(Vehicle, shipment.assigned_vehicle_id)
        if vehicle is not None and vehicle.status == VehicleStatus.ASSIGNED:
            vehicle.status = VehicleStatus.AVAILABLE
            vehicle.driver_id = None


def _driver_has_other_active(db: Session, driver_id: UUID, shipment_id: UUID) -> bool:
    return (
        db.scalar(
            select(Shipment.id).where(
                Shipment.assigned_driver_id == driver_id,
                Shipment.id != shipment_id,
                Shipment.status.in_(ACTIVE_SHIPMENT_STATUSES),
            )
        )
        is not None
    )


def _vehicle_has_other_active(db: Session, vehicle_id: UUID, shipment_id: UUID) -> bool:
    return (
        db.scalar(
            select(Shipment.id).where(
                Shipment.assigned_vehicle_id == vehicle_id,
                Shipment.id != shipment_id,
                Shipment.status.in_(ACTIVE_SHIPMENT_STATUSES),
            )
        )
        is not None
    )


def shipment_for_actor(db: Session, actor: User, shipment_id: UUID) -> Shipment:
    return _visible_shipment(db, actor, shipment_id)


def _visible_shipment(db: Session, actor: User, shipment_id: UUID) -> Shipment:
    shipment = _require_loaded(db, shipment_id)
    if actor.role in {UserRole.ADMIN, UserRole.FLEET_MANAGER}:
        return shipment
    if actor.role == UserRole.CUSTOMER and shipment.customer_id == actor.id:
        return shipment
    if actor.role == UserRole.DRIVER:
        driver = shipment.assigned_driver
        if driver is not None and driver.user_id == actor.id:
            return shipment
    raise AppError(404, "Shipment not found")


def _driver_id_for_user(db: Session, actor: User) -> UUID:
    driver_id = db.scalar(select(Driver.id).where(Driver.user_id == actor.id))
    if driver_id is None:
        raise AppError(404, "Driver profile not found")
    return driver_id


def _shipment_query():
    return select(Shipment).options(
        joinedload(Shipment.customer),
        joinedload(Shipment.assigned_driver).joinedload(Driver.user),
        joinedload(Shipment.assigned_vehicle),
        joinedload(Shipment.delivery),
    )


def _require_loaded(db: Session, shipment_id: UUID) -> Shipment:
    shipment = db.scalar(_shipment_query().where(Shipment.id == shipment_id))
    if shipment is None:
        raise AppError(404, "Shipment not found")
    return shipment


def _next_tracking_number(db: Session) -> str:
    year = datetime.now(UTC).year
    prefix = f"FF-{year}-"
    latest = db.scalar(
        select(Shipment.tracking_number)
        .where(Shipment.tracking_number.like(f"{prefix}%"))
        .order_by(Shipment.tracking_number.desc())
        .limit(1)
    )
    sequence = 1
    if latest:
        try:
            sequence = int(latest.rsplit("-", 1)[1]) + 1
        except (IndexError, ValueError):
            sequence = 1
    return f"{prefix}{sequence:06d}"


def _to_read(shipment: Shipment) -> ShipmentRead:
    driver = shipment.assigned_driver
    vehicle = shipment.assigned_vehicle
    delivery = shipment.delivery
    return ShipmentRead(
        id=shipment.id,
        tracking_number=shipment.tracking_number,
        customer_id=shipment.customer_id,
        customer_name=shipment.customer.name,
        pickup_address=shipment.pickup_address,
        pickup_latitude=shipment.pickup_latitude,
        pickup_longitude=shipment.pickup_longitude,
        delivery_address=shipment.delivery_address,
        delivery_latitude=shipment.delivery_latitude,
        delivery_longitude=shipment.delivery_longitude,
        package_description=shipment.package_description,
        priority=shipment.priority,
        status=shipment.status,
        assigned_driver_id=shipment.assigned_driver_id,
        driver_name=driver.user.name if driver is not None else None,
        assigned_vehicle_id=shipment.assigned_vehicle_id,
        vehicle_number=vehicle.vehicle_number if vehicle is not None else None,
        delivery_id=delivery.id if delivery is not None else None,
        failure_reason=delivery.failure_reason if delivery is not None else None,
        failure_code=delivery.failure_code if delivery is not None else None,
        failure_notes=delivery.failure_notes if delivery is not None else None,
        recipient_name=delivery.recipient_name if delivery is not None else None,
        geofence_entered_at=delivery.geofence_entered_at if delivery is not None else None,
        delivered_at=delivery.delivered_at if delivery is not None else None,
        failed_at=delivery.failed_at if delivery is not None else None,
        pod_available=bool(delivery and delivery.pod_photo_key),
        created_at=shipment.created_at,
        updated_at=shipment.updated_at,
    )
