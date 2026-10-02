from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_roles
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.shipment import (
    AssignmentRequest,
    ShipmentCreate,
    ShipmentRead,
    ShipmentUpdate,
    StatusUpdateRequest,
)
from app.services import shipment_service

router = APIRouter(tags=["shipments"])

_dispatchers = require_roles(UserRole.ADMIN, UserRole.FLEET_MANAGER)


@router.get("/driver/shipments", response_model=list[ShipmentRead])
def driver_shipments(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(UserRole.DRIVER)),
) -> list[ShipmentRead]:
    return shipment_service.list_driver_shipments(db, current_user)


@router.get("/shipments", response_model=list[ShipmentRead])
def list_shipments(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[ShipmentRead]:
    return shipment_service.list_shipments(db, current_user)


@router.post("/shipments", response_model=ShipmentRead, status_code=status.HTTP_201_CREATED)
def create_shipment(
    payload: ShipmentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ShipmentRead:
    return shipment_service.create_shipment(db, current_user, payload)


@router.get("/shipments/{shipment_id}", response_model=ShipmentRead)
def get_shipment(
    shipment_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ShipmentRead:
    return shipment_service.get_shipment(db, current_user, shipment_id)


@router.put("/shipments/{shipment_id}", response_model=ShipmentRead)
def update_shipment(
    shipment_id: UUID,
    payload: ShipmentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ShipmentRead:
    return shipment_service.update_shipment(db, current_user, shipment_id, payload)


@router.post("/shipments/{shipment_id}/assign", response_model=ShipmentRead)
def assign_shipment(
    shipment_id: UUID,
    payload: AssignmentRequest,
    db: Session = Depends(get_db),
    _: User = Depends(_dispatchers),
) -> ShipmentRead:
    return shipment_service.assign_shipment(db, shipment_id, payload)


@router.post("/shipments/{shipment_id}/status", response_model=ShipmentRead)
def update_shipment_status(
    shipment_id: UUID,
    payload: StatusUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ShipmentRead:
    return shipment_service.update_status(db, current_user, shipment_id, payload)
