from datetime import datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import and_, func, or_, select
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.models.delivery import Delivery
from app.models.delivery_event import DeliveryEvent
from app.models.delivery_operation import DeliveryOperation
from app.models.driver import Driver
from app.models.enums import ACTIVE_SHIPMENT_STATUSES, DriverStatus, ShipmentStatus, VehicleStatus
from app.models.fuel_record import FuelRecord
from app.models.location import Location
from app.models.shipment import Shipment
from app.models.user import User
from app.models.vehicle import Vehicle
from app.schemas.operations import (
    DriverActivity,
    DriverOperations,
    DriverPerformance,
    FleetUtilization,
    FleetVehicle,
    FuelBrief,
    OperationsOverview,
    VehicleOperations,
)
from app.services.geofence import distance_meters
from app.services.metrics import delivery_duration_minutes, money, outcome_rates, quantity
from app.services.periods import resolve_range

_ON_DELIVERY = (
    ShipmentStatus.PICKED_UP,
    ShipmentStatus.IN_TRANSIT,
    ShipmentStatus.ARRIVING,
)
_DISTANCE_POINT_LIMIT = 200


def overview(db: Session) -> OperationsOverview:
    fleet = utilization(db)
    liters, cost, average = _fuel_totals(db)
    return OperationsOverview(
        fleet=fleet,
        fuel_liters=quantity(liters),
        fuel_cost=money(cost),
        average_price_per_liter=None if average is None else money(average),
        average_delivery_duration_minutes=_average_duration(db),
    )


def utilization(db: Session) -> FleetUtilization:
    vehicle_counts = dict(
        db.execute(select(Vehicle.status, func.count()).group_by(Vehicle.status)).all()
    )
    driver_counts = dict(db.execute(select(Driver.status, func.count()).group_by(Driver.status)).all())
    total_vehicles = sum(vehicle_counts.values())
    inactive_vehicles = vehicle_counts.get(VehicleStatus.INACTIVE, 0)
    total_drivers = sum(driver_counts.values())
    completed = _count_deliveries(db, ShipmentStatus.DELIVERED)
    failed = _count_deliveries(db, ShipmentStatus.FAILED)
    completion, _failure = outcome_rates(completed, failed)
    on_delivery = db.scalar(
        select(func.count(func.distinct(Shipment.assigned_vehicle_id))).where(
            Shipment.status.in_(_ON_DELIVERY),
            Shipment.assigned_vehicle_id.is_not(None),
        )
    )
    return FleetUtilization(
        total_vehicles=total_vehicles,
        active_vehicles=total_vehicles - inactive_vehicles,
        available_vehicles=vehicle_counts.get(VehicleStatus.AVAILABLE, 0),
        assigned_vehicles=vehicle_counts.get(VehicleStatus.ASSIGNED, 0),
        vehicles_on_delivery=int(on_delivery or 0),
        inactive_vehicles=inactive_vehicles,
        total_drivers=total_drivers,
        available_drivers=driver_counts.get(DriverStatus.AVAILABLE, 0),
        drivers_on_delivery=driver_counts.get(DriverStatus.ON_DELIVERY, 0),
        inactive_drivers=driver_counts.get(DriverStatus.INACTIVE, 0),
        active_deliveries=_count_active(db),
        completed_deliveries=completed,
        failed_deliveries=failed,
        completion_rate=completion,
        as_of=datetime.now().astimezone(),
    )


def list_driver_performance(db: Session, start_date, end_date) -> list[DriverPerformance]:
    _start_day, _end_day, start_at, end_at = resolve_range(start_date, end_date)
    drivers = db.scalars(select(Driver).join(Driver.user).order_by(User.name)).all()
    return [performance_for(db, driver, start_at, end_at, include_distance=False) for driver in drivers]


def driver_detail(db: Session, driver_id: UUID, start_date, end_date) -> DriverOperations:
    _start_day, _end_day, start_at, end_at = resolve_range(start_date, end_date)
    driver = _driver(db, driver_id)
    vehicle = db.scalar(select(Vehicle).where(Vehicle.driver_id == driver.id))
    active = db.scalar(
        select(Shipment).where(
            Shipment.assigned_driver_id == driver.id,
            Shipment.status.in_(ACTIVE_SHIPMENT_STATUSES),
        )
    )
    return DriverOperations(
        driver_id=driver.id,
        driver_name=driver.user.name,
        status=driver.status.value,
        vehicle_id=None if vehicle is None else vehicle.id,
        vehicle_number=None if vehicle is None else vehicle.vehicle_number,
        active_shipment_id=None if active is None else active.id,
        active_tracking_number=None if active is None else active.tracking_number,
        active_shipment_status=None if active is None else active.status.value,
        performance=performance_for(db, driver, start_at, end_at, include_distance=True),
        recent_activity=_driver_activity(db, driver.id),
    )


def driver_performance(db: Session, driver_id: UUID, start_date, end_date) -> DriverPerformance:
    _start_day, _end_day, start_at, end_at = resolve_range(start_date, end_date)
    driver = _driver(db, driver_id)
    return performance_for(db, driver, start_at, end_at, include_distance=True)


def fleet_board(db: Session, status: str | None) -> list[FleetVehicle]:
    statement = select(Vehicle).order_by(Vehicle.vehicle_number)
    if status:
        allowed = {item.value for item in VehicleStatus}
        if status not in allowed and status != "ON_DELIVERY":
            raise AppError(400, "Unknown vehicle filter")
        if status == "ON_DELIVERY":
            statement = statement.where(
                Vehicle.id.in_(
                    select(Shipment.assigned_vehicle_id).where(
                        Shipment.status.in_(_ON_DELIVERY),
                        Shipment.assigned_vehicle_id.is_not(None),
                    )
                )
            )
        else:
            statement = statement.where(Vehicle.status == VehicleStatus(status))
    vehicles = db.scalars(statement).all()
    return [_fleet_vehicle(db, vehicle) for vehicle in vehicles]


def vehicle_detail(db: Session, vehicle_id: UUID) -> VehicleOperations:
    vehicle = db.get(Vehicle, vehicle_id)
    if vehicle is None:
        raise AppError(404, "Vehicle not found")
    board = _fleet_vehicle(db, vehicle)
    fuel_rows = db.scalars(
        select(FuelRecord)
        .where(FuelRecord.vehicle_id == vehicle.id)
        .order_by(FuelRecord.fuel_date.desc())
        .limit(8)
    ).all()
    delivery_count = db.scalar(
        select(func.count()).select_from(Delivery).where(Delivery.vehicle_id == vehicle.id)
    )
    return VehicleOperations(
        **board.model_dump(),
        model=vehicle.model,
        fuel_efficiency_km_per_liter=None
        if vehicle.fuel_efficiency_km_per_liter is None
        else quantity(vehicle.fuel_efficiency_km_per_liter),
        delivery_count=int(delivery_count or 0),
        recent_fuel=[
            FuelBrief(
                id=row.id,
                fuel_date=row.fuel_date,
                liters=quantity(row.liters),
                total_cost=money(row.total_cost),
                fuel_station=row.fuel_station,
                odometer_km=None if row.odometer_km is None else format(row.odometer_km, "f"),
            )
            for row in fuel_rows
        ],
        recent_events=_vehicle_activity(db, vehicle.id),
    )


def performance_for(
    db: Session,
    driver: Driver,
    start_at: datetime,
    end_at: datetime,
    *,
    include_distance: bool,
) -> DriverPerformance:
    completed = _finished_count(db, driver.id, ShipmentStatus.DELIVERED, Delivery.delivered_at, start_at, end_at)
    failed = _finished_count(db, driver.id, ShipmentStatus.FAILED, Delivery.failed_at, start_at, end_at)
    assigned = _assigned_count(db, driver.id, start_at, end_at)
    active = db.scalar(
        select(func.count())
        .select_from(Delivery)
        .where(Delivery.driver_id == driver.id, Delivery.status.in_(ACTIVE_SHIPMENT_STATUSES))
    )
    completion, failure = outcome_rates(completed, failed)
    distance = _average_distance_km(db, driver.id, start_at, end_at) if include_distance else None
    return DriverPerformance(
        driver_id=driver.id,
        driver_name=driver.user.name,
        current_status=driver.status.value,
        assigned_deliveries=assigned,
        completed_deliveries=completed,
        failed_deliveries=failed,
        active_delivery_count=int(active or 0),
        completion_rate=completion,
        failure_rate=failure,
        average_delivery_duration_minutes=_average_duration(db, driver.id, start_at, end_at),
        average_distance_km=distance,
    )


def _driver(db: Session, driver_id: UUID) -> Driver:
    driver = db.scalar(select(Driver).join(Driver.user).where(Driver.id == driver_id))
    if driver is None:
        raise AppError(404, "Driver not found")
    return driver


def _count_deliveries(db: Session, status: ShipmentStatus) -> int:
    return int(db.scalar(select(func.count()).select_from(Delivery).where(Delivery.status == status)) or 0)


def _count_active(db: Session) -> int:
    return int(
        db.scalar(select(func.count()).select_from(Delivery).where(Delivery.status.in_(ACTIVE_SHIPMENT_STATUSES)))
        or 0
    )


def _finished_count(db, driver_id, status, column, start_at, end_at) -> int:
    return int(
        db.scalar(
            select(func.count()).select_from(Delivery).where(
                Delivery.driver_id == driver_id,
                Delivery.status == status,
                column >= start_at,
                column < end_at,
            )
        )
        or 0
    )


def _assigned_count(db: Session, driver_id: UUID, start_at: datetime, end_at: datetime) -> int:
    assigned_event = (
        select(DeliveryEvent.id)
        .where(
            DeliveryEvent.delivery_id == Delivery.id,
            DeliveryEvent.event_type == "ASSIGNED",
            DeliveryEvent.created_at >= start_at,
            DeliveryEvent.created_at < end_at,
        )
        .exists()
    )
    return int(
        db.scalar(
            select(func.count()).select_from(Delivery).where(
                Delivery.driver_id == driver_id,
                or_(
                    assigned_event,
                    and_(Delivery.picked_up_at >= start_at, Delivery.picked_up_at < end_at),
                    and_(Delivery.delivered_at >= start_at, Delivery.delivered_at < end_at),
                    and_(Delivery.failed_at >= start_at, Delivery.failed_at < end_at),
                ),
            )
        )
        or 0
    )


def _average_duration(
    db: Session,
    driver_id: UUID | None = None,
    start_at: datetime | None = None,
    end_at: datetime | None = None,
) -> float | None:
    statement = select(Delivery.picked_up_at, Delivery.delivered_at).where(
        Delivery.picked_up_at.is_not(None),
        Delivery.delivered_at.is_not(None),
        Delivery.status == ShipmentStatus.DELIVERED,
    )
    if driver_id is not None:
        statement = statement.where(Delivery.driver_id == driver_id)
    if start_at is not None and end_at is not None:
        statement = statement.where(Delivery.delivered_at >= start_at, Delivery.delivered_at < end_at)
    minutes = [
        delivery_duration_minutes(picked_up, delivered)
        for picked_up, delivered in db.execute(statement).all()
    ]
    usable = [item for item in minutes if item is not None]
    if not usable:
        return None
    return round(sum(usable) / len(usable), 1)


def _average_distance_km(db: Session, driver_id: UUID, start_at: datetime, end_at: datetime) -> float | None:
    windows = db.execute(
        select(Delivery.picked_up_at, Delivery.delivered_at).where(
            Delivery.driver_id == driver_id,
            Delivery.status == ShipmentStatus.DELIVERED,
            Delivery.picked_up_at.is_not(None),
            Delivery.delivered_at.is_not(None),
            Delivery.delivered_at >= start_at,
            Delivery.delivered_at < end_at,
        )
    ).all()
    distances: list[float] = []
    for picked_up, delivered in windows:
        points = db.execute(
            select(Location.latitude, Location.longitude)
            .where(
                Location.driver_id == driver_id,
                Location.timestamp >= picked_up,
                Location.timestamp <= delivered,
            )
            .order_by(Location.timestamp)
            .limit(_DISTANCE_POINT_LIMIT + 1)
        ).all()
        if len(points) < 2 or len(points) > _DISTANCE_POINT_LIMIT:
            continue
        meters = 0.0
        for previous, current in zip(points, points[1:]):
            meters += distance_meters(previous[0], previous[1], current[0], current[1])
        distances.append(meters / 1000)
    if not distances:
        return None
    return round(sum(distances) / len(distances), 2)


def _fuel_totals(db: Session) -> tuple[Decimal, Decimal, Decimal | None]:
    liters, cost = db.execute(
        select(
            func.coalesce(func.sum(FuelRecord.liters), 0),
            func.coalesce(func.sum(FuelRecord.total_cost), 0),
        )
    ).one()
    liters = Decimal(liters)
    cost = Decimal(cost)
    average = None if liters == 0 else (cost / liters).quantize(Decimal("0.01"))
    return liters, cost, average


def _fleet_vehicle(db: Session, vehicle: Vehicle) -> FleetVehicle:
    driver_name = None
    if vehicle.driver_id is not None:
        driver = db.scalar(select(Driver).join(Driver.user).where(Driver.id == vehicle.driver_id))
        if driver is not None:
            driver_name = driver.user.name
    shipment = db.scalar(
        select(Shipment)
        .where(
            Shipment.assigned_vehicle_id == vehicle.id,
            Shipment.status.in_(ACTIVE_SHIPMENT_STATUSES),
        )
        .order_by(Shipment.updated_at.desc())
    )
    latitude = longitude = recorded = None
    if vehicle.driver_id is not None:
        location = db.scalar(
            select(Location)
            .where(Location.driver_id == vehicle.driver_id)
            .order_by(Location.timestamp.desc())
            .limit(1)
        )
        if location is not None:
            latitude = location.latitude
            longitude = location.longitude
            recorded = location.timestamp
    liters, cost = db.execute(
        select(
            func.coalesce(func.sum(FuelRecord.liters), 0),
            func.coalesce(func.sum(FuelRecord.total_cost), 0),
        ).where(FuelRecord.vehicle_id == vehicle.id)
    ).one()
    return FleetVehicle(
        vehicle_id=vehicle.id,
        vehicle_number=vehicle.vehicle_number,
        vehicle_type=vehicle.vehicle_type,
        status=vehicle.status.value,
        fuel_type=vehicle.fuel_type,
        service_status=vehicle.service_status,
        current_odometer_km=None if vehicle.current_odometer_km is None else format(vehicle.current_odometer_km, "f"),
        last_service_date=vehicle.last_service_date,
        next_service_due_km=None if vehicle.next_service_due_km is None else format(vehicle.next_service_due_km, "f"),
        driver_id=vehicle.driver_id,
        driver_name=driver_name,
        shipment_id=None if shipment is None else shipment.id,
        tracking_number=None if shipment is None else shipment.tracking_number,
        shipment_status=None if shipment is None else shipment.status.value,
        latitude=latitude,
        longitude=longitude,
        location_recorded_at=recorded,
        fuel_liters=quantity(Decimal(liters)),
        fuel_cost=money(Decimal(cost)),
    )


def _driver_activity(db: Session, driver_id: UUID) -> list[DriverActivity]:
    events = db.execute(
        select(DeliveryEvent, Delivery, Shipment)
        .join(Delivery, Delivery.id == DeliveryEvent.delivery_id)
        .join(Shipment, Shipment.id == Delivery.shipment_id)
        .where(Delivery.driver_id == driver_id)
        .order_by(DeliveryEvent.created_at.desc())
        .limit(12)
    ).all()
    activity = [
        DriverActivity(
            delivery_id=delivery.id,
            tracking_number=shipment.tracking_number,
            shipment_status=shipment.status.value,
            event_type=event.event_type,
            created_at=event.created_at,
        )
        for event, delivery, shipment in events
    ]
    syncs = db.execute(
        select(DeliveryOperation, Delivery, Shipment)
        .join(Delivery, Delivery.id == DeliveryOperation.delivery_id)
        .join(Shipment, Shipment.id == Delivery.shipment_id)
        .where(DeliveryOperation.driver_id == driver_id)
        .order_by(DeliveryOperation.created_at.desc())
        .limit(5)
    ).all()
    activity.extend(
        DriverActivity(
            delivery_id=delivery.id,
            tracking_number=shipment.tracking_number,
            shipment_status=shipment.status.value,
            event_type=f"SYNC_{operation.action}",
            created_at=operation.created_at,
        )
        for operation, delivery, shipment in syncs
    )
    activity.sort(key=lambda item: item.created_at, reverse=True)
    return activity[:12]


def _vehicle_activity(db: Session, vehicle_id: UUID) -> list[DriverActivity]:
    rows = db.execute(
        select(DeliveryEvent, Delivery, Shipment)
        .join(Delivery, Delivery.id == DeliveryEvent.delivery_id)
        .join(Shipment, Shipment.id == Delivery.shipment_id)
        .where(Delivery.vehicle_id == vehicle_id)
        .order_by(DeliveryEvent.created_at.desc())
        .limit(12)
    ).all()
    return [
        DriverActivity(
            delivery_id=delivery.id,
            tracking_number=shipment.tracking_number,
            shipment_status=shipment.status.value,
            event_type=event.event_type,
            created_at=event.created_at,
        )
        for event, delivery, shipment in rows
    ]
