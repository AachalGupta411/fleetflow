from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.errors import AppError
from app.core.security import hash_password
from app.models.driver import Driver
from app.models.enums import ACTIVE_SHIPMENT_STATUSES, DriverStatus, UserRole
from app.models.shipment import Shipment
from app.models.user import User
from app.schemas.driver import DriverCreate, DriverRead, DriverUpdate
from app.services.db_utils import commit, email_taken

MANUAL_DRIVER_STATUSES = {DriverStatus.AVAILABLE, DriverStatus.OFFLINE, DriverStatus.INACTIVE}


def list_drivers(db: Session) -> list[DriverRead]:
    drivers = db.scalars(
        select(Driver).options(joinedload(Driver.user)).order_by(Driver.created_at.desc())
    ).all()
    return [_to_read(driver) for driver in drivers]


def get_driver(db: Session, driver_id: UUID) -> DriverRead:
    driver = _load(db, driver_id)
    if driver is None:
        raise AppError(404, "Driver not found")
    return _to_read(driver)


def get_driver_for_user(db: Session, user: User) -> DriverRead:
    driver = db.scalar(select(Driver).options(joinedload(Driver.user)).where(Driver.user_id == user.id))
    if driver is None:
        raise AppError(404, "Driver profile not found")
    return _to_read(driver)


def create_driver(db: Session, data: DriverCreate) -> DriverRead:
    email = data.email.lower()
    if email_taken(db, email):
        raise AppError(409, "Email is already in use")
    if _license_taken(db, data.license_number.strip()):
        raise AppError(409, "License number is already in use")
    user = User(
        name=data.name.strip(),
        email=email,
        phone=data.phone.strip() if data.phone else None,
        password_hash=hash_password(data.password),
        role=UserRole.DRIVER,
        is_active=True,
    )
    driver = Driver(
        user=user,
        license_number=data.license_number.strip(),
        license_expiry=data.license_expiry,
        status=DriverStatus.AVAILABLE,
    )
    db.add(driver)
    commit(db)
    created = _load(db, driver.id)
    return _to_read(created)


def update_driver(db: Session, driver_id: UUID, data: DriverUpdate) -> DriverRead:
    driver = _load(db, driver_id)
    if driver is None:
        raise AppError(404, "Driver not found")
    if data.license_number is not None:
        license_number = data.license_number.strip()
        if _license_taken(db, license_number, ignore_id=driver.id):
            raise AppError(409, "License number is already in use")
        driver.license_number = license_number
    if data.license_expiry is not None:
        driver.license_expiry = data.license_expiry
    if data.name is not None:
        driver.user.name = data.name.strip()
    if data.phone is not None:
        driver.user.phone = data.phone.strip() or None
    if data.status is not None and data.status != driver.status:
        if data.status == DriverStatus.ON_DELIVERY:
            raise AppError(409, "Driver status changes to on delivery only through assignment")
        if data.status not in MANUAL_DRIVER_STATUSES:
            raise AppError(409, "That driver status cannot be set directly")
        if data.status != DriverStatus.AVAILABLE and _has_active_shipment(db, driver.id):
            raise AppError(409, "Driver still has an active shipment")
        if data.status == DriverStatus.AVAILABLE and _has_active_shipment(db, driver.id):
            raise AppError(409, "Driver still has an active shipment")
        driver.status = data.status
    commit(db)
    refreshed = _load(db, driver.id)
    return _to_read(refreshed)


def _load(db: Session, driver_id: UUID) -> Driver | None:
    return db.scalar(select(Driver).options(joinedload(Driver.user)).where(Driver.id == driver_id))


def _license_taken(db: Session, license_number: str, ignore_id: UUID | None = None) -> bool:
    statement = select(Driver.id).where(Driver.license_number == license_number)
    if ignore_id is not None:
        statement = statement.where(Driver.id != ignore_id)
    return db.scalar(statement) is not None


def _has_active_shipment(db: Session, driver_id: UUID) -> bool:
    return (
        db.scalar(
            select(Shipment.id).where(
                Shipment.assigned_driver_id == driver_id,
                Shipment.status.in_(ACTIVE_SHIPMENT_STATUSES),
            )
        )
        is not None
    )


def _to_read(driver: Driver) -> DriverRead:
    return DriverRead(
        id=driver.id,
        user_id=driver.user_id,
        name=driver.user.name,
        email=driver.user.email,
        phone=driver.user.phone,
        license_number=driver.license_number,
        license_expiry=driver.license_expiry,
        status=driver.status,
        is_active=driver.user.is_active,
        created_at=driver.created_at,
        updated_at=driver.updated_at,
    )
