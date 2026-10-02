import base64
import binascii
from datetime import UTC, datetime, timedelta
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.core.config import get_settings
from app.core.errors import AppError
from app.models.delivery import Delivery
from app.models.delivery_event import DeliveryEvent
from app.models.delivery_operation import DeliveryOperation
from app.models.driver import Driver
from app.models.enums import ShipmentStatus, UserRole
from app.models.shipment import Shipment
from app.models.user import User
from app.schemas.delivery import (
    FAILURE_REASONS,
    ArrivalRequest,
    DeliveryEventRead,
    FailureRequest,
    ProofRead,
    SyncAction,
    SyncItemResult,
    SyncRequest,
    SyncResponse,
)
from app.schemas.shipment import StatusUpdateRequest
from app.services import shipment_service
from app.services.db_utils import commit
from app.services.delivery_events import add_event
from app.services.geofence import distance_meters, geofence_radius_meters
from app.services.notification_service import announce, staff_ids
from app.services.route_service import RouteLookupError, resolve_destination
from app.services.storage import get_storage, validate_image


def delivery_config() -> dict:
    settings = get_settings()
    provider = settings.storage_provider.strip().lower() or "local"
    storage_ready = provider == "local" or bool(settings.supabase_url and settings.supabase_service_role_key)
    return {
        "geofence_radius_meters": geofence_radius_meters(),
        "storage_configured": storage_ready,
        "push_configured": bool(settings.firebase_credentials_file),
    }


def arrive(db: Session, actor: User, delivery_id: UUID, data: ArrivalRequest) -> ProofRead:
    if data.client_operation_id:
        existing = _existing_operation(db, data.client_operation_id)
        if existing is not None:
            return _proof(db, existing.delivery_id, duplicate=True)
    delivery, shipment = _driver_delivery(db, actor, delivery_id)
    _arrive(db, actor, delivery, shipment, data.latitude, data.longitude, data.accuracy)
    if data.client_operation_id:
        _remember(db, data.client_operation_id, delivery, actor, "ARRIVE", shipment.status.value)
    commit(db)
    return _proof(db, delivery.id)


def fail(db: Session, actor: User, delivery_id: UUID, data: FailureRequest) -> ProofRead:
    if data.reason not in FAILURE_REASONS:
        raise AppError(422, "Choose a valid failure reason")
    if data.client_operation_id:
        existing = _existing_operation(db, data.client_operation_id)
        if existing is not None:
            return _proof(db, existing.delivery_id, duplicate=True)
    delivery, shipment = _driver_delivery(db, actor, delivery_id)
    _fail(db, actor, delivery, shipment, data.reason, data.notes, data.latitude, data.longitude)
    if data.client_operation_id:
        _remember(db, data.client_operation_id, delivery, actor, "FAIL", "FAILED")
    commit(db)
    return _proof(db, delivery.id)


def submit_pod(
    db: Session,
    actor: User,
    delivery_id: UUID,
    *,
    recipient_name: str,
    recipient_phone: str | None,
    notes: str | None,
    latitude: float,
    longitude: float,
    accuracy: float | None,
    photo: bytes,
    photo_type: str,
    signature: bytes,
    signature_type: str,
    client_operation_id: str,
) -> ProofRead:
    existing = _existing_operation(db, client_operation_id)
    if existing is not None:
        return _proof(db, existing.delivery_id, duplicate=True)
    name = recipient_name.strip()
    if len(name) < 2:
        raise AppError(422, "Recipient name is required")
    photo_type = validate_image(photo, photo_type)
    signature_type = validate_image(signature, signature_type, signature=True)
    delivery, shipment = _driver_delivery(db, actor, delivery_id)
    if shipment.status != ShipmentStatus.ARRIVING:
        raise AppError(409, "Mark the delivery arriving before proof of delivery")
    if shipment.status in {ShipmentStatus.DELIVERED, ShipmentStatus.FAILED}:
        raise AppError(409, "This delivery is already finished")
    destination = _destination(shipment)
    _assert_inside(latitude, longitude, destination)
    storage = get_storage()
    photo_key = storage.save(photo, photo_type, "pod")
    signature_key = storage.save(signature, signature_type, "signatures")
    now = datetime.now(UTC)
    if delivery.geofence_entered_at is None:
        delivery.geofence_entered_at = now
        delivery.arrived_at = now
        add_event(
            db,
            delivery_id=delivery.id,
            event_type="GEOFENCE_ENTERED",
            actor_user_id=actor.id,
            latitude=latitude,
            longitude=longitude,
        )
    delivery.recipient_name = name
    delivery.recipient_phone = recipient_phone.strip() if recipient_phone else None
    delivery.pod_notes = notes.strip() if notes else None
    delivery.pod_photo_key = photo_key
    delivery.signature_key = signature_key
    delivery.delivery_latitude = latitude
    delivery.delivery_longitude = longitude
    delivery.delivery_accuracy = accuracy
    delivery.delivered_at = now
    delivery.completed_at = now
    delivery.status = ShipmentStatus.DELIVERED
    shipment.status = ShipmentStatus.DELIVERED
    add_event(db, delivery_id=delivery.id, event_type="POD_SUBMITTED", actor_user_id=actor.id, note=name)
    add_event(
        db,
        delivery_id=delivery.id,
        event_type="DELIVERED",
        actor_user_id=actor.id,
        latitude=latitude,
        longitude=longitude,
    )
    shipment_service.release_assignment(db, shipment)
    announce(
        db,
        kind="DELIVERY_COMPLETED",
        shipment=shipment,
        title="Delivery completed",
        body=f"{shipment.tracking_number} was delivered to {name}.",
        user_ids=[shipment.customer_id, *staff_ids(db)],
    )
    _remember(db, client_operation_id, delivery, actor, "POD", "DELIVERED")
    commit(db)
    return _proof(db, delivery.id)


def proof(db: Session, actor: User, delivery_id: UUID) -> ProofRead:
    _visible_delivery(db, actor, delivery_id)
    return _proof(db, delivery_id)


def proof_file(db: Session, actor: User, delivery_id: UUID, kind: str) -> tuple[bytes, str]:
    delivery, _shipment = _visible_delivery(db, actor, delivery_id)
    key = delivery.pod_photo_key if kind == "photo" else delivery.signature_key
    if not key:
        raise AppError(404, "That proof file is not available")
    return get_storage().read(key)


def list_events(db: Session, actor: User, delivery_id: UUID) -> list[DeliveryEventRead]:
    delivery, _shipment = _visible_delivery(db, actor, delivery_id)
    rows = db.scalars(
        select(DeliveryEvent).where(DeliveryEvent.delivery_id == delivery.id).order_by(DeliveryEvent.created_at.asc())
    ).all()
    return [
        DeliveryEventRead(
            id=row.id,
            delivery_id=row.delivery_id,
            event_type=row.event_type,
            latitude=row.latitude,
            longitude=row.longitude,
            note=row.note,
            created_at=row.created_at,
        )
        for row in rows
    ]


def recent_events(db: Session, actor: User) -> list[DeliveryEventRead]:
    if actor.role not in {UserRole.ADMIN, UserRole.FLEET_MANAGER}:
        raise AppError(403, "You do not have access to this resource")
    rows = db.scalars(select(DeliveryEvent).order_by(DeliveryEvent.created_at.desc()).limit(30)).all()
    return [
        DeliveryEventRead(
            id=row.id,
            delivery_id=row.delivery_id,
            event_type=row.event_type,
            latitude=row.latitude,
            longitude=row.longitude,
            note=row.note,
            created_at=row.created_at,
        )
        for row in rows
    ]


def sync_actions(db: Session, actor: User, data: SyncRequest) -> SyncResponse:
    if actor.role != UserRole.DRIVER:
        raise AppError(403, "Only a driver can synchronize delivery actions")
    results: list[SyncItemResult] = []
    for action in data.actions:
        results.append(_sync_one(db, actor, action))
    return SyncResponse(results=results)


def _sync_one(db: Session, actor: User, action: SyncAction) -> SyncItemResult:
    existing = _existing_operation(db, action.client_operation_id)
    if existing is not None:
        return SyncItemResult(
            client_operation_id=action.client_operation_id,
            status="duplicate",
            detail=existing.result_status,
        )
    try:
        kind = action.action.upper()
        if kind == "ARRIVE":
            arrive(
                db,
                actor,
                action.delivery_id,
                ArrivalRequest(
                    latitude=float(action.payload["latitude"]),
                    longitude=float(action.payload["longitude"]),
                    accuracy=action.payload.get("accuracy"),
                    client_operation_id=action.client_operation_id,
                ),
            )
        elif kind == "FAIL":
            fail(
                db,
                actor,
                action.delivery_id,
                FailureRequest(
                    reason=str(action.payload["reason"]),
                    notes=action.payload.get("notes"),
                    latitude=action.payload.get("latitude"),
                    longitude=action.payload.get("longitude"),
                    client_operation_id=action.client_operation_id,
                ),
            )
        elif kind == "STATUS":
            shipment_service.update_status(
                db,
                actor,
                _delivery_shipment_id(db, action.delivery_id),
                StatusUpdateRequest(status=ShipmentStatus(action.payload["status"])),
            )
            delivery = db.get(Delivery, action.delivery_id)
            _remember(db, action.client_operation_id, delivery, actor, "STATUS", action.payload["status"])
            commit(db)
        elif kind == "POD":
            submit_pod(
                db,
                actor,
                action.delivery_id,
                recipient_name=str(action.payload.get("recipient_name") or ""),
                recipient_phone=action.payload.get("recipient_phone"),
                notes=action.payload.get("notes"),
                latitude=float(action.payload["latitude"]),
                longitude=float(action.payload["longitude"]),
                accuracy=action.payload.get("accuracy"),
                photo=_decode_file(action.payload.get("photo_base64"), "photo"),
                photo_type=str(action.payload.get("photo_type") or "image/jpeg"),
                signature=_decode_file(action.payload.get("signature_base64"), "signature"),
                signature_type=str(action.payload.get("signature_type") or "image/png"),
                client_operation_id=action.client_operation_id,
            )
        else:
            raise AppError(422, "Unknown delivery action")
    except (AppError, KeyError, TypeError, ValueError) as exc:
        db.rollback()
        detail = exc.detail if isinstance(exc, AppError) else "The queued action is invalid"
        return SyncItemResult(client_operation_id=action.client_operation_id, status="error", detail=detail)
    return SyncItemResult(client_operation_id=action.client_operation_id, status="applied", detail="ok")


def _arrive(
    db: Session,
    actor: User,
    delivery: Delivery,
    shipment: Shipment,
    latitude: float,
    longitude: float,
    accuracy: float | None,
) -> None:
    if shipment.status in {ShipmentStatus.DELIVERED, ShipmentStatus.FAILED, ShipmentStatus.CANCELLED}:
        raise AppError(409, "This delivery is already finished")
    if shipment.status not in {ShipmentStatus.IN_TRANSIT, ShipmentStatus.ARRIVING}:
        raise AppError(409, "Start the trip before recording arrival")
    if delivery.geofence_entered_at is not None:
        return
    destination = _destination(shipment)
    _assert_inside(latitude, longitude, destination)
    now = datetime.now(UTC)
    if shipment.delivery_latitude is None or shipment.delivery_longitude is None:
        shipment.delivery_latitude = destination[0]
        shipment.delivery_longitude = destination[1]
    shipment.status = ShipmentStatus.ARRIVING
    delivery.status = ShipmentStatus.ARRIVING
    delivery.geofence_entered_at = now
    delivery.arrived_at = now
    delivery.delivery_latitude = latitude
    delivery.delivery_longitude = longitude
    delivery.delivery_accuracy = accuracy
    add_event(
        db,
        delivery_id=delivery.id,
        event_type="GEOFENCE_ENTERED",
        actor_user_id=actor.id,
        latitude=latitude,
        longitude=longitude,
        note=f"Within {geofence_radius_meters()} m",
    )
    add_event(db, delivery_id=delivery.id, event_type="ARRIVING", actor_user_id=actor.id)
    announce(
        db,
        kind="DRIVER_ARRIVING",
        shipment=shipment,
        title="Driver arriving",
        body=f"The driver is arriving with {shipment.tracking_number}.",
        user_ids=[shipment.customer_id],
    )


def _fail(
    db: Session,
    actor: User,
    delivery: Delivery,
    shipment: Shipment,
    reason: str,
    notes: str | None,
    latitude: float | None,
    longitude: float | None,
) -> None:
    if shipment.status not in {ShipmentStatus.IN_TRANSIT, ShipmentStatus.ARRIVING}:
        raise AppError(409, "That status change is not allowed")
    now = datetime.now(UTC)
    shipment.status = ShipmentStatus.FAILED
    delivery.status = ShipmentStatus.FAILED
    delivery.failure_code = reason
    delivery.failure_reason = reason.replace("_", " ").title()
    delivery.failure_notes = notes.strip() if notes else None
    delivery.failed_at = now
    delivery.completed_at = now
    delivery.delivery_latitude = latitude
    delivery.delivery_longitude = longitude
    add_event(
        db,
        delivery_id=delivery.id,
        event_type="FAILED",
        actor_user_id=actor.id,
        latitude=latitude,
        longitude=longitude,
        note=reason,
    )
    shipment_service.release_assignment(db, shipment)
    announce(
        db,
        kind="DELIVERY_FAILED",
        shipment=shipment,
        title="Delivery failed",
        body=f"{shipment.tracking_number} could not be delivered ({delivery.failure_reason}).",
        user_ids=[shipment.customer_id, *staff_ids(db)],
    )
    if delivery.driver_id is not None:
        since = datetime.now(UTC) - timedelta(days=7)
        recent_failures = db.scalar(
            select(func.count())
            .select_from(Delivery)
            .where(
                Delivery.driver_id == delivery.driver_id,
                Delivery.failed_at.is_not(None),
                Delivery.failed_at >= since,
            )
        )
        if recent_failures is not None and recent_failures >= 2:
            announce(
                db,
                kind="REPEATED_DELIVERY_FAILURE",
                shipment=shipment,
                title="Repeated delivery failure",
                body=f"{shipment.tracking_number} is another failed delivery for this driver in the last 7 days.",
                user_ids=staff_ids(db),
            )


def _destination(shipment: Shipment) -> tuple[float, float]:
    latitude = None if shipment.delivery_latitude is None else float(shipment.delivery_latitude)
    longitude = None if shipment.delivery_longitude is None else float(shipment.delivery_longitude)
    try:
        return resolve_destination(latitude, longitude, shipment.delivery_address)
    except RouteLookupError as exc:
        raise AppError(422, str(exc)) from exc


def _assert_inside(latitude: float, longitude: float, destination: tuple[float, float]) -> None:
    radius = geofence_radius_meters()
    distance = distance_meters(latitude, longitude, destination[0], destination[1])
    if distance > radius:
        raise AppError(422, f"You are {int(distance)} m from the delivery, outside the {radius} m geofence")


def _driver_delivery(db: Session, actor: User, delivery_id: UUID) -> tuple[Delivery, Shipment]:
    if actor.role != UserRole.DRIVER:
        raise AppError(403, "Only the assigned driver can update this delivery")
    delivery, shipment = _load_delivery(db, delivery_id)
    driver = shipment.assigned_driver
    if driver is None or driver.user_id != actor.id:
        raise AppError(404, "Delivery not found")
    return delivery, shipment


def _visible_delivery(db: Session, actor: User, delivery_id: UUID) -> tuple[Delivery, Shipment]:
    delivery, shipment = _load_delivery(db, delivery_id)
    shipment_service.shipment_for_actor(db, actor, shipment.id)
    return delivery, shipment


def _load_delivery(db: Session, delivery_id: UUID) -> tuple[Delivery, Shipment]:
    delivery = db.scalar(
        select(Delivery)
        .where(Delivery.id == delivery_id)
        .options(joinedload(Delivery.shipment).joinedload(Shipment.assigned_driver).joinedload(Driver.user))
    )
    if delivery is None or delivery.shipment is None:
        raise AppError(404, "Delivery not found")
    return delivery, delivery.shipment


def _delivery_shipment_id(db: Session, delivery_id: UUID) -> UUID:
    shipment_id = db.scalar(select(Delivery.shipment_id).where(Delivery.id == delivery_id))
    if shipment_id is None:
        raise AppError(404, "Delivery not found")
    return shipment_id


def _existing_operation(db: Session, client_operation_id: str) -> DeliveryOperation | None:
    return db.scalar(select(DeliveryOperation).where(DeliveryOperation.client_operation_id == client_operation_id))


def _remember(db: Session, client_operation_id: str, delivery: Delivery, actor: User, action: str, result: str) -> None:
    driver_id = delivery.driver_id
    if driver_id is None:
        driver_id = db.scalar(select(Driver.id).where(Driver.user_id == actor.id))
    db.add(
        DeliveryOperation(
            client_operation_id=client_operation_id,
            delivery_id=delivery.id,
            driver_id=driver_id,
            action=action,
            result_status=result,
        )
    )


def _proof(db: Session, delivery_id: UUID, *, duplicate: bool = False) -> ProofRead:
    delivery = db.get(Delivery, delivery_id)
    if delivery is None:
        raise AppError(404, "Delivery not found")
    return ProofRead(
        delivery_id=delivery.id,
        shipment_id=delivery.shipment_id,
        recipient_name=delivery.recipient_name,
        recipient_phone=delivery.recipient_phone,
        notes=delivery.pod_notes,
        delivered_at=delivery.delivered_at,
        failed_at=delivery.failed_at,
        failure_code=delivery.failure_code,
        failure_reason=delivery.failure_reason,
        failure_notes=delivery.failure_notes,
        geofence_entered_at=delivery.geofence_entered_at,
        photo_available=bool(delivery.pod_photo_key),
        signature_available=bool(delivery.signature_key),
        duplicate=duplicate,
    )


def _decode_file(value: object, label: str) -> bytes:
    if not isinstance(value, str) or not value:
        raise AppError(422, f"The {label} file is required")
    try:
        return base64.b64decode(value, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise AppError(422, f"The {label} file is not valid base64") from exc
