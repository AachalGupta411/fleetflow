from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.core.security import hash_password
from app.models.enums import ACTIVE_SHIPMENT_STATUSES, UserRole
from app.models.shipment import Shipment
from app.models.user import User
from app.schemas.user import UserCreate, UserRead, UserUpdate
from app.services.db_utils import commit, email_taken

MANAGED_ROLES = {UserRole.ADMIN, UserRole.FLEET_MANAGER, UserRole.CUSTOMER}


def list_users(db: Session) -> list[UserRead]:
    users = db.scalars(select(User).order_by(User.created_at.desc())).all()
    return [UserRead.model_validate(user) for user in users]


def get_user(db: Session, user_id: UUID) -> UserRead:
    user = db.get(User, user_id)
    if user is None:
        raise AppError(404, "User not found")
    return UserRead.model_validate(user)


def create_user(db: Session, data: UserCreate) -> UserRead:
    if data.role not in MANAGED_ROLES:
        raise AppError(422, "Create drivers with the driver endpoint")
    email = data.email.lower()
    if email_taken(db, email):
        raise AppError(409, "Email is already in use")
    user = User(
        name=data.name.strip(),
        email=email,
        phone=_phone(data.phone),
        password_hash=hash_password(data.password),
        role=data.role,
        is_active=True,
    )
    db.add(user)
    commit(db)
    db.refresh(user)
    return UserRead.model_validate(user)


def update_user(db: Session, actor: User, user_id: UUID, data: UserUpdate) -> UserRead:
    user = db.get(User, user_id)
    if user is None:
        raise AppError(404, "User not found")
    if data.role is not None and data.role != user.role:
        if actor.id == user.id:
            raise AppError(403, "You cannot change your own role")
        if data.role == UserRole.DRIVER or user.role == UserRole.DRIVER:
            raise AppError(422, "Create drivers with the driver endpoint")
        if data.role not in MANAGED_ROLES:
            raise AppError(422, "That role cannot be assigned here")
        user.role = data.role
    if data.is_active is False and actor.id == user.id:
        raise AppError(409, "You cannot deactivate your own account")
    if data.is_active is False and _has_active_shipment(db, user):
        raise AppError(409, "This user still has an active shipment")
    if data.name is not None:
        user.name = data.name.strip()
    if data.phone is not None:
        user.phone = _phone(data.phone)
    if data.is_active is not None:
        user.is_active = data.is_active
    if data.password is not None:
        user.password_hash = hash_password(data.password)
    commit(db)
    db.refresh(user)
    return UserRead.model_validate(user)


def _phone(value: str | None) -> str | None:
    if value is None:
        return None
    stripped = value.strip()
    return stripped or None


def _has_active_shipment(db: Session, user: User) -> bool:
    if user.driver_profile is None:
        return (
            db.scalar(
                select(Shipment.id).where(
                    Shipment.customer_id == user.id,
                    Shipment.status.in_(ACTIVE_SHIPMENT_STATUSES),
                )
            )
            is not None
        )
    return (
        db.scalar(
            select(Shipment.id).where(
                Shipment.assigned_driver_id == user.driver_profile.id,
                Shipment.status.in_(ACTIVE_SHIPMENT_STATUSES),
            )
        )
        is not None
    )
