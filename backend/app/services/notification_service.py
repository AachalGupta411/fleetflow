from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.models.device_token import DeviceToken
from app.models.enums import UserRole
from app.models.notification import Notification
from app.models.shipment import Shipment
from app.models.user import User
from app.services.db_utils import commit


def register_token(db: Session, user: User, token: str, platform: str) -> DeviceToken:
    cleaned = token.strip()
    if len(cleaned) < 10:
        from app.core.errors import AppError

        raise AppError(422, "Device token is too short")
    existing = db.scalar(select(DeviceToken).where(DeviceToken.token == cleaned))
    if existing is None:
        existing = DeviceToken(user_id=user.id, token=cleaned, platform=platform)
        db.add(existing)
    else:
        existing.user_id = user.id
        existing.platform = platform
    commit(db)
    db.refresh(existing)
    return existing


def unregister_token(db: Session, user: User, token: str) -> None:
    row = db.scalar(select(DeviceToken).where(DeviceToken.token == token.strip(), DeviceToken.user_id == user.id))
    if row is not None:
        db.delete(row)
        commit(db)


def list_notifications(db: Session, user: User) -> list[Notification]:
    return list(
        db.scalars(
            select(Notification).where(Notification.user_id == user.id).order_by(Notification.created_at.desc()).limit(50)
        ).all()
    )


def announce(db: Session, *, kind: str, shipment: Shipment, title: str, body: str, user_ids: list[UUID]) -> None:
    """Store an in-app alert. Push is sent only when Firebase credentials exist."""
    push_ready = bool(get_settings().firebase_credentials_file)
    for user_id in dict.fromkeys(user_ids):
        already = db.scalar(
            select(Notification.id).where(
                Notification.user_id == user_id,
                Notification.shipment_id == shipment.id,
                Notification.kind == kind,
            )
        )
        if already is not None:
            continue
        sent = False
        if push_ready:
            tokens = db.scalars(select(DeviceToken.token).where(DeviceToken.user_id == user_id)).all()
            sent = bool(tokens) and _send_push(list(tokens), title, body)
        db.add(
            Notification(
                user_id=user_id,
                shipment_id=shipment.id,
                kind=kind,
                title=title,
                body=body,
                push_sent=sent,
            )
        )


def announce_operational(db: Session, *, kind: str, title: str, body: str) -> None:
    """One in-app alert per staff user and title. Push sending stays on the existing path."""
    for user_id in staff_ids(db):
        already = db.scalar(
            select(Notification.id).where(
                Notification.user_id == user_id,
                Notification.kind == kind,
                Notification.title == title,
                Notification.shipment_id.is_(None),
            )
        )
        if already is not None:
            continue
        db.add(
            Notification(
                user_id=user_id,
                shipment_id=None,
                kind=kind,
                title=title,
                body=body,
                push_sent=False,
            )
        )


def staff_ids(db: Session) -> list[UUID]:
    return list(
        db.scalars(
            select(User.id).where(User.role.in_([UserRole.ADMIN, UserRole.FLEET_MANAGER]), User.is_active.is_(True))
        ).all()
    )


def _send_push(tokens: list[str], title: str, body: str) -> bool:
    """Firebase Cloud Messaging is not called until a service account file is configured.

    Returning False keeps push_sent honest. The in-app notification row is still stored.
    """
    path = get_settings().firebase_credentials_file
    if not path:
        return False
    from pathlib import Path

    if not Path(path).is_file():
        return False
    # The HTTP v1 send requires a Google OAuth token from the service account.
    # Without that exchange implemented, a configured file still must not be reported as delivered.
    _ = (tokens, title, body)
    return False
