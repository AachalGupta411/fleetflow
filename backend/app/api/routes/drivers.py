from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_roles
from app.core.errors import AppError
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.driver import DriverCreate, DriverRead, DriverUpdate
from app.services import driver_service

router = APIRouter(prefix="/drivers", tags=["drivers"])

_managers = require_roles(UserRole.ADMIN, UserRole.FLEET_MANAGER)


@router.get("", response_model=list[DriverRead])
def list_drivers(
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> list[DriverRead]:
    return driver_service.list_drivers(db)


@router.post("", response_model=DriverRead, status_code=status.HTTP_201_CREATED)
def create_driver(
    payload: DriverCreate,
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> DriverRead:
    return driver_service.create_driver(db, payload)


@router.get("/me", response_model=DriverRead)
def my_driver_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_roles(UserRole.DRIVER)),
) -> DriverRead:
    return driver_service.get_driver_for_user(db, current_user)


@router.get("/{driver_id}", response_model=DriverRead)
def get_driver(
    driver_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> DriverRead:
    driver = driver_service.get_driver(db, driver_id)
    if current_user.role == UserRole.DRIVER and driver.user_id != current_user.id:
        raise AppError(403, "You do not have access to this resource")
    if current_user.role not in {UserRole.ADMIN, UserRole.FLEET_MANAGER, UserRole.DRIVER}:
        raise AppError(403, "You do not have access to this resource")
    return driver


@router.put("/{driver_id}", response_model=DriverRead)
def update_driver(
    driver_id: UUID,
    payload: DriverUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(_managers),
) -> DriverRead:
    return driver_service.update_driver(db, driver_id, payload)
