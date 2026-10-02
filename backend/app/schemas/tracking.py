from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import ShipmentStatus


class LocationCreate(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    accuracy: float | None = Field(default=None, ge=0)
    speed: float | None = Field(default=None, ge=0)
    heading: float | None = Field(default=None, ge=0, le=360)


class LocationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    driver_id: UUID
    vehicle_id: UUID | None
    latitude: float
    longitude: float
    accuracy: float | None
    speed: float | None
    heading: float | None
    timestamp: datetime
    freshness: str


class FleetDriverRead(BaseModel):
    driver_id: UUID
    driver_name: str
    vehicle_id: UUID | None
    vehicle_number: str | None
    latitude: float | None
    longitude: float | None
    last_updated: datetime | None
    freshness: str
    shipment_id: UUID
    tracking_number: str
    status: ShipmentStatus


class RoutePoint(BaseModel):
    latitude: float
    longitude: float


class ShipmentTrackingRead(BaseModel):
    shipment_id: UUID
    tracking_number: str
    status: ShipmentStatus
    driver_id: UUID | None
    driver_name: str | None
    vehicle_id: UUID | None
    vehicle_number: str | None
    latitude: float | None
    longitude: float | None
    last_updated: datetime | None
    freshness: str
    delivery_address: str
    destination_latitude: float | None
    destination_longitude: float | None
    route_available: bool
    distance_meters: int | None
    duration_seconds: int | None
    eta: datetime | None
    route_points: list[RoutePoint]
    message: str | None
    routes_configured: bool


class TrackingCapabilities(BaseModel):
    routes_configured: bool
