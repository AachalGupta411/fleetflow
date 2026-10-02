from uuid import UUID

from sqlalchemy.orm import Session

from app.models.delivery_event import DeliveryEvent


def add_event(
    db: Session,
    *,
    delivery_id: UUID,
    event_type: str,
    actor_user_id: UUID | None = None,
    latitude: float | None = None,
    longitude: float | None = None,
    note: str | None = None,
) -> None:
    db.add(
        DeliveryEvent(
            delivery_id=delivery_id,
            event_type=event_type,
            actor_user_id=actor_user_id,
            latitude=latitude,
            longitude=longitude,
            note=note,
        )
    )
