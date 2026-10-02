from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_roles
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.tracking import (
    FleetDriverRead,
    LocationCreate,
    LocationRead,
    ShipmentTrackingRead,
    TrackingCapabilities,
)
from app.services import tracking_service

router = APIRouter(prefix="/tracking", tags=["tracking"])

_dispatchers = require_roles(UserRole.ADMIN, UserRole.FLEET_MANAGER)


@router.get("/capabilities", response_model=TrackingCapabilities)
def tracking_capabilities(_: User = Depends(get_current_user)) -> TrackingCapabilities:
    return tracking_service.capabilities()


@router.post("/location", response_model=LocationRead, status_code=status.HTTP_201_CREATED)
def submit_location(
    payload: LocationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(UserRole.DRIVER)),
) -> LocationRead:
    return tracking_service.record_location(db, current_user, payload)


@router.get("/fleet", response_model=list[FleetDriverRead])
def fleet_locations(
    db: Session = Depends(get_db),
    _: User = Depends(_dispatchers),
) -> list[FleetDriverRead]:
    return tracking_service.fleet(db)


@router.get("/drivers/{driver_id}/location", response_model=LocationRead)
def driver_location(
    driver_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> LocationRead:
    return tracking_service.driver_location(db, current_user, driver_id)


@router.get("/shipments/{shipment_id}", response_model=ShipmentTrackingRead)
def shipment_tracking(
    shipment_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ShipmentTrackingRead:
    return tracking_service.shipment_tracking(db, current_user, shipment_id)
