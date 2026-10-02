import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, Float, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.types import Uuid

from app.db.base import Base
from app.models.enums import ShipmentStatus, shipment_status_enum

if TYPE_CHECKING:
    from app.models.driver import Driver
    from app.models.shipment import Shipment
    from app.models.vehicle import Vehicle


class Delivery(Base):
    __tablename__ = "deliveries"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    shipment_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("shipments.id", ondelete="CASCADE"), nullable=False, unique=True
    )
    driver_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(as_uuid=True), ForeignKey("drivers.id"))
    vehicle_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(as_uuid=True), ForeignKey("vehicles.id"))
    status: Mapped[ShipmentStatus] = mapped_column(
        shipment_status_enum, nullable=False, default=ShipmentStatus.PENDING, index=True
    )
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    picked_up_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    arrived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    delivered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    failed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    failure_reason: Mapped[str | None] = mapped_column(Text)
    failure_code: Mapped[str | None] = mapped_column(String(40))
    failure_notes: Mapped[str | None] = mapped_column(Text)
    recipient_name: Mapped[str | None] = mapped_column(String(120))
    recipient_phone: Mapped[str | None] = mapped_column(String(20))
    pod_photo_key: Mapped[str | None] = mapped_column(String(255))
    signature_key: Mapped[str | None] = mapped_column(String(255))
    pod_notes: Mapped[str | None] = mapped_column(Text)
    delivery_latitude: Mapped[float | None] = mapped_column(Float)
    delivery_longitude: Mapped[float | None] = mapped_column(Float)
    delivery_accuracy: Mapped[float | None] = mapped_column(Float)
    geofence_entered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )

    shipment: Mapped["Shipment"] = relationship(back_populates="delivery")
    driver: Mapped["Driver | None"] = relationship(foreign_keys=[driver_id])
    vehicle: Mapped["Vehicle | None"] = relationship(foreign_keys=[vehicle_id])
