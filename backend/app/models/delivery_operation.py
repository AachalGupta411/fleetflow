import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import Uuid

from app.db.base import Base


class DeliveryOperation(Base):
    """Idempotency record so a queued driver action is applied once."""

    __tablename__ = "delivery_operations"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    client_operation_id: Mapped[str] = mapped_column(String(80), nullable=False, unique=True)
    delivery_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("deliveries.id"), nullable=False)
    driver_id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("drivers.id"), nullable=False)
    action: Mapped[str] = mapped_column(String(40), nullable=False)
    result_status: Mapped[str] = mapped_column(String(40), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    note: Mapped[str | None] = mapped_column(Text)
