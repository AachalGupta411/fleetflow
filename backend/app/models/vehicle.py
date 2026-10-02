import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import Date, DateTime, ForeignKey, Integer, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.types import Uuid

from app.db.base import Base
from app.models.enums import VehicleStatus, vehicle_status_enum

if TYPE_CHECKING:
    from app.models.driver import Driver


class Vehicle(Base):
    __tablename__ = "vehicles"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    vehicle_number: Mapped[str] = mapped_column(String(20), nullable=False, unique=True)
    vehicle_type: Mapped[str] = mapped_column(String(40), nullable=False)
    model: Mapped[str] = mapped_column(String(80), nullable=False)
    capacity: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[VehicleStatus] = mapped_column(
        vehicle_status_enum, nullable=False, default=VehicleStatus.AVAILABLE, index=True
    )
    driver_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(as_uuid=True), ForeignKey("drivers.id"))
    fuel_type: Mapped[str | None] = mapped_column(String(20))
    fuel_efficiency_km_per_liter: Mapped[Decimal | None] = mapped_column(Numeric(6, 2))
    current_odometer_km: Mapped[Decimal | None] = mapped_column(Numeric(10, 1))
    last_service_date: Mapped[date | None] = mapped_column(Date)
    next_service_due_km: Mapped[Decimal | None] = mapped_column(Numeric(10, 1))
    service_status: Mapped[str] = mapped_column(String(20), nullable=False, default="OK", server_default="OK")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )

    driver: Mapped["Driver | None"] = relationship(back_populates="vehicles")
