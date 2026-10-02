import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Date, DateTime, ForeignKey, Index, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import Uuid

from app.db.base import Base


class FuelRecord(Base):
    __tablename__ = "fuel_records"
    __table_args__ = (
        Index("ix_fuel_records_vehicle_id_fuel_date", "vehicle_id", "fuel_date"),
        Index("ix_fuel_records_driver_id", "driver_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    vehicle_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("vehicles.id"), nullable=False)
    driver_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(as_uuid=True), ForeignKey("drivers.id"))
    liters: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    price_per_liter: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    total_cost: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    odometer_km: Mapped[Decimal | None] = mapped_column(Numeric(10, 1))
    fuel_station: Mapped[str | None] = mapped_column(String(120))
    fuel_date: Mapped[date] = mapped_column(Date, nullable=False)
    notes: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
