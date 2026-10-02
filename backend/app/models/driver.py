import uuid
from datetime import date, datetime
from typing import TYPE_CHECKING

from sqlalchemy import Date, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.types import Uuid

from app.db.base import Base
from app.models.enums import DriverStatus, driver_status_enum

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.vehicle import Vehicle


class Driver(Base):
    __tablename__ = "drivers"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id"), nullable=False, unique=True
    )
    license_number: Mapped[str] = mapped_column(String(40), nullable=False, unique=True)
    license_expiry: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[DriverStatus] = mapped_column(
        driver_status_enum, nullable=False, default=DriverStatus.AVAILABLE, index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship(back_populates="driver_profile")
    vehicles: Mapped[list["Vehicle"]] = relationship(back_populates="driver")
