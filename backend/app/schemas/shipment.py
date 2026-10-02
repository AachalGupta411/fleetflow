from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import ShipmentPriority, ShipmentStatus


class ShipmentCreate(BaseModel):
    pickup_address: str = Field(min_length=3, max_length=500)
    delivery_address: str = Field(min_length=3, max_length=500)
    package_description: str = Field(min_length=2, max_length=500)
    priority: ShipmentPriority = ShipmentPriority.NORMAL


class ShipmentUpdate(BaseModel):
    pickup_address: str | None = Field(default=None, min_length=3, max_length=500)
    delivery_address: str | None = Field(default=None, min_length=3, max_length=500)
    package_description: str | None = Field(default=None, min_length=2, max_length=500)
    priority: ShipmentPriority | None = None


class AssignmentRequest(BaseModel):
    driver_id: UUID
    vehicle_id: UUID


class StatusUpdateRequest(BaseModel):
    status: ShipmentStatus
    failure_reason: str | None = Field(default=None, max_length=500)


class ShipmentRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    tracking_number: str
    customer_id: UUID
    customer_name: str
    pickup_address: str
    pickup_latitude: Decimal | None
    pickup_longitude: Decimal | None
    delivery_address: str
    delivery_latitude: Decimal | None
    delivery_longitude: Decimal | None
    package_description: str
    priority: ShipmentPriority
    status: ShipmentStatus
    assigned_driver_id: UUID | None
    driver_name: str | None
    assigned_vehicle_id: UUID | None
    vehicle_number: str | None
    delivery_id: UUID | None
    failure_reason: str | None
    failure_code: str | None = None
    failure_notes: str | None = None
    recipient_name: str | None = None
    geofence_entered_at: datetime | None = None
    delivered_at: datetime | None = None
    failed_at: datetime | None = None
    pod_available: bool = False
    created_at: datetime
    updated_at: datetime
