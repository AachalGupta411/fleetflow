from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

FAILURE_REASONS = (
    "CUSTOMER_UNAVAILABLE",
    "WRONG_ADDRESS",
    "CUSTOMER_REFUSED",
    "ACCESS_ISSUE",
    "VEHICLE_ISSUE",
    "DAMAGED_PACKAGE",
    "OTHER",
)


class ArrivalRequest(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    accuracy: float | None = Field(default=None, ge=0)
    client_operation_id: str | None = Field(default=None, min_length=8, max_length=80)


class FailureRequest(BaseModel):
    reason: str
    notes: str | None = Field(default=None, max_length=500)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    client_operation_id: str | None = Field(default=None, min_length=8, max_length=80)


class DeliveryEventRead(BaseModel):
    id: UUID
    delivery_id: UUID
    event_type: str
    latitude: float | None
    longitude: float | None
    note: str | None
    created_at: datetime


class ProofRead(BaseModel):
    delivery_id: UUID
    shipment_id: UUID
    recipient_name: str | None
    recipient_phone: str | None
    notes: str | None
    delivered_at: datetime | None
    failed_at: datetime | None
    failure_code: str | None
    failure_reason: str | None
    failure_notes: str | None
    geofence_entered_at: datetime | None
    photo_available: bool
    signature_available: bool
    duplicate: bool = False


class SyncAction(BaseModel):
    client_operation_id: str = Field(min_length=8, max_length=80)
    delivery_id: UUID
    action: str
    payload: dict = Field(default_factory=dict)
    client_timestamp: datetime | None = None


class SyncRequest(BaseModel):
    actions: list[SyncAction] = Field(min_length=1, max_length=20)


class SyncItemResult(BaseModel):
    client_operation_id: str
    status: str
    detail: str


class SyncResponse(BaseModel):
    results: list[SyncItemResult]


class DeviceTokenRequest(BaseModel):
    token: str = Field(min_length=10, max_length=512)
    platform: str = Field(pattern="^(android|ios|web)$")


class NotificationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    kind: str
    title: str
    body: str
    shipment_id: UUID | None
    push_sent: bool
    created_at: datetime


class DeliveryConfig(BaseModel):
    geofence_radius_meters: int
    storage_configured: bool
    push_configured: bool
