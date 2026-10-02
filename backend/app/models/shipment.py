import uuid
from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.types import Uuid

from app.db.base import Base
from app.models.enums import (
    ShipmentPriority,
    ShipmentStatus,
    shipment_priority_enum,
    shipment_status_enum,
)

if TYPE_CHECKING:
    from app.models.delivery import Delivery
    from app.models.driver import Driver
    from app.models.user import User
    from app.models.vehicle import Vehicle


class Shipment(Base):
    __tablename__ = "shipments"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tracking_number: Mapped[str] = mapped_column(String(20), nullable=False, unique=True)
    customer_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True
    )
    pickup_address: Mapped[str] = mapped_column(Text, nullable=False)
    pickup_latitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    pickup_longitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    delivery_address: Mapped[str] = mapped_column(Text, nullable=False)
    delivery_latitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    delivery_longitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    package_description: Mapped[str] = mapped_column(Text, nullable=False)
    priority: Mapped[ShipmentPriority] = mapped_column(
        shipment_priority_enum, nullable=False, default=ShipmentPriority.NORMAL
    )
    status: Mapped[ShipmentStatus] = mapped_column(
        shipment_status_enum, nullable=False, default=ShipmentStatus.PENDING, index=True
    )
    assigned_driver_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("drivers.id"), index=True
    )
    assigned_vehicle_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("vehicles.id"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )

    customer: Mapped["User"] = relationship(back_populates="shipments", foreign_keys=[customer_id])
    assigned_driver: Mapped["Driver | None"] = relationship(foreign_keys=[assigned_driver_id])
    assigned_vehicle: Mapped["Vehicle | None"] = relationship(foreign_keys=[assigned_vehicle_id])
    delivery: Mapped["Delivery | None"] = relationship(back_populates="shipment", uselist=False)
