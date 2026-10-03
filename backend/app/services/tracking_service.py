from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import distinct_on
from sqlalchemy.orm import Session, joinedload

from app.core.errors import AppError
from app.models.driver import Driver
from app.models.enums import ACTIVE_SHIPMENT_STATUSES, ShipmentStatus, UserRole
from app.models.location import Location
from app.models.shipment import Shipment
from app.models.user import User
from app.schemas.tracking import (
    FleetDriverRead,
    LocationCreate,
    LocationRead,
    RoutePoint,
    ShipmentTrackingRead,
    TrackingCapabilities,
)
from app.services.freshness import classify_freshness
from app.services.route_service import estimate_route, routes_configured
from app.services.shipment_service import shipment_for_actor

TRACKING_STATUSES = {
    ShipmentStatus.PICKED_UP,
    ShipmentStatus.IN_TRANSIT,
    ShipmentStatus.ARRIVING,
}


def record_location(db: Session, actor: User, data: LocationCreate) -> LocationRead:
    if actor.role != UserRole.DRIVER:
        raise AppError(403, "Only a driver can submit a location")
    driver = _driver_for_user(db, actor)
    shipment = _tracking_shipment(db, driver.id)
    if shipment is None:
        assigned = _current_shipment(db, driver.id)
        if assigned is not None and assigned.status == ShipmentStatus.ASSIGNED:
            raise AppError(409, "Start the delivery before sharing location.")
        raise AppError(409, "No active delivery.")
    location = Location(
        driver_id=driver.id,
        vehicle_id=shipment.assigned_vehicle_id,
        latitude=data.latitude,
        longitude=data.longitude,
        accuracy=data.accuracy,
        speed=data.speed,
        heading=data.heading,
        timestamp=datetime.now(UTC),
    )
    db.add(location)
    db.commit()
    db.refresh(location)
    return _location_read(location)


def driver_location(db: Session, actor: User, driver_id: UUID) -> LocationRead:
    _authorize_driver_location(db, actor, driver_id)
    location = _latest_locations(db, [driver_id]).get(driver_id)
    if location is None:
        raise AppError(404, "No location recorded for this driver")
    return _location_read(location)


def fleet(db: Session) -> list[FleetDriverRead]:
    shipments = _active_shipments(db)
    chosen: dict[UUID, Shipment] = {}
    for shipment in shipments:
        driver_id = shipment.assigned_driver_id
        if driver_id is not None and driver_id not in chosen:
            chosen[driver_id] = shipment
    locations = _latest_locations(db, list(chosen))
    now = datetime.now(UTC)
    rows: list[FleetDriverRead] = []
    for driver_id, shipment in chosen.items():
        driver = shipment.assigned_driver
        user = driver.user if driver is not None else None
        vehicle = shipment.assigned_vehicle
        location = locations.get(driver_id)
        rows.append(
            FleetDriverRead(
                driver_id=driver_id,
                driver_name=user.name if user is not None else "Driver",
                vehicle_id=shipment.assigned_vehicle_id,
                vehicle_number=vehicle.vehicle_number if vehicle is not None else None,
                latitude=location.latitude if location is not None else None,
                longitude=location.longitude if location is not None else None,
                last_updated=location.timestamp if location is not None else None,
                freshness=classify_freshness(None if location is None else location.timestamp, now),
                shipment_id=shipment.id,
                tracking_number=shipment.tracking_number,
                status=shipment.status,
            )
        )
    rows.sort(key=lambda item: item.driver_name)
    return rows


def shipment_tracking(db: Session, actor: User, shipment_id: UUID) -> ShipmentTrackingRead:
    shipment = shipment_for_actor(db, actor, shipment_id)
    driver = shipment.assigned_driver
    user = driver.user if driver is not None else None
    vehicle = shipment.assigned_vehicle
    location = None
    if driver is not None:
        location = _latest_locations(db, [driver.id]).get(driver.id)
    now = datetime.now(UTC)
    origin_lat = None if location is None else location.latitude
    origin_lng = None if location is None else location.longitude
    dest_lat = None if shipment.delivery_latitude is None else float(shipment.delivery_latitude)
    dest_lng = None if shipment.delivery_longitude is None else float(shipment.delivery_longitude)
    route = estimate_route(origin_lat, origin_lng, dest_lat, dest_lng, shipment.delivery_address)
    message = route.message
    if location is None and driver is not None and message is None:
        message = "Driver location is currently unavailable."
    if driver is None:
        message = "No driver is assigned to this shipment."
    return ShipmentTrackingRead(
        shipment_id=shipment.id,
        tracking_number=shipment.tracking_number,
        status=shipment.status,
        driver_id=None if driver is None else driver.id,
        driver_name=None if user is None else user.name,
        vehicle_id=shipment.assigned_vehicle_id,
        vehicle_number=None if vehicle is None else vehicle.vehicle_number,
        latitude=origin_lat,
        longitude=origin_lng,
        last_updated=None if location is None else location.timestamp,
        freshness=classify_freshness(None if location is None else location.timestamp, now),
        delivery_address=shipment.delivery_address,
        destination_latitude=route.destination_latitude if route.destination_latitude is not None else dest_lat,
        destination_longitude=route.destination_longitude if route.destination_longitude is not None else dest_lng,
        route_available=route.available,
        distance_meters=route.distance_meters,
        duration_seconds=route.duration_seconds,
        eta=route.eta,
        route_points=[RoutePoint(latitude=lat, longitude=lng) for lat, lng in route.points],
        message=message,
        routes_configured=routes_configured(),
    )


def capabilities() -> TrackingCapabilities:
    return TrackingCapabilities(routes_configured=routes_configured())


def _authorize_driver_location(db: Session, actor: User, driver_id: UUID) -> None:
    if actor.role in {UserRole.ADMIN, UserRole.FLEET_MANAGER}:
        return
    if actor.role == UserRole.DRIVER:
        driver = _driver_for_user(db, actor)
        if driver.id == driver_id:
            return
        raise AppError(403, "You can only view your own location")
    raise AppError(403, "You do not have access to this location")


def _driver_for_user(db: Session, actor: User) -> Driver:
    driver = db.scalar(select(Driver).where(Driver.user_id == actor.id))
    if driver is None:
        raise AppError(404, "Driver profile not found")
    return driver


def _tracking_shipment(db: Session, driver_id: UUID) -> Shipment | None:
    return db.scalar(
        select(Shipment)
        .where(
            Shipment.assigned_driver_id == driver_id,
            Shipment.status.in_(TRACKING_STATUSES),
        )
        .order_by(Shipment.updated_at.desc())
    )


def _current_shipment(db: Session, driver_id: UUID) -> Shipment | None:
    return db.scalar(
        select(Shipment)
        .where(
            Shipment.assigned_driver_id == driver_id,
            Shipment.status.in_(ACTIVE_SHIPMENT_STATUSES),
        )
        .order_by(Shipment.updated_at.desc())
    )


def _active_shipments(db: Session) -> list[Shipment]:
    return list(
        db.scalars(
            select(Shipment)
            .where(
                Shipment.status.in_(ACTIVE_SHIPMENT_STATUSES),
                Shipment.assigned_driver_id.is_not(None),
            )
            .options(
                joinedload(Shipment.assigned_driver).joinedload(Driver.user),
                joinedload(Shipment.assigned_vehicle),
            )
            .order_by(Shipment.updated_at.desc())
        ).unique()
    )


def _latest_locations(db: Session, driver_ids: list[UUID]) -> dict[UUID, Location]:
    if not driver_ids:
        return {}
    rows = db.scalars(
        select(Location)
        .where(Location.driver_id.in_(driver_ids))
        .ext(distinct_on(Location.driver_id))
        .order_by(Location.driver_id, Location.timestamp.desc())
    ).all()
    return {row.driver_id: row for row in rows}


def _location_read(location: Location) -> LocationRead:
    return LocationRead(
        id=location.id,
        driver_id=location.driver_id,
        vehicle_id=location.vehicle_id,
        latitude=location.latitude,
        longitude=location.longitude,
        accuracy=location.accuracy,
        speed=location.speed,
        heading=location.heading,
        timestamp=location.timestamp,
        freshness=classify_freshness(location.timestamp, datetime.now(UTC)),
    )
