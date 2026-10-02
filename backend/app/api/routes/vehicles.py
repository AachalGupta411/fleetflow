from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import require_roles
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.vehicle import VehicleCreate, VehicleRead, VehicleUpdate
from app.services import vehicle_service

router = APIRouter(prefix="/vehicles", tags=["vehicles"])

_managers = require_roles(UserRole.ADMIN, UserRole.FLEET_MANAGER)


@router.get("", response_model=list[VehicleRead])
def list_vehicles(
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> list[VehicleRead]:
    return vehicle_service.list_vehicles(db)


@router.post("", response_model=VehicleRead, status_code=status.HTTP_201_CREATED)
def create_vehicle(
    payload: VehicleCreate,
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> VehicleRead:
    return vehicle_service.create_vehicle(db, payload)


@router.get("/{vehicle_id}", response_model=VehicleRead)
def get_vehicle(
    vehicle_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> VehicleRead:
    return vehicle_service.get_vehicle(db, vehicle_id)


@router.put("/{vehicle_id}", response_model=VehicleRead)
def update_vehicle(
    vehicle_id: UUID,
    payload: VehicleUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> VehicleRead:
    return vehicle_service.update_vehicle(db, vehicle_id, payload)
