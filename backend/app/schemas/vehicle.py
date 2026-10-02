from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import VehicleStatus


class VehicleCreate(BaseModel):
    vehicle_number: str = Field(min_length=3, max_length=20)
    vehicle_type: str = Field(min_length=2, max_length=40)
    model: str = Field(min_length=1, max_length=80)
    capacity: int = Field(gt=0, le=100000)


class VehicleUpdate(BaseModel):
    vehicle_number: str | None = Field(default=None, min_length=3, max_length=20)
    vehicle_type: str | None = Field(default=None, min_length=2, max_length=40)
    model: str | None = Field(default=None, min_length=1, max_length=80)
    capacity: int | None = Field(default=None, gt=0, le=100000)
    status: VehicleStatus | None = None
    fuel_type: str | None = None
    fuel_efficiency_km_per_liter: Decimal | None = Field(default=None, gt=0, le=99)
    last_service_date: date | None = None
    next_service_due_km: Decimal | None = Field(default=None, ge=0)


class VehicleRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    vehicle_number: str
    vehicle_type: str
    model: str
    capacity: int
    status: VehicleStatus
    driver_id: UUID | None
    driver_name: str | None
    fuel_type: str | None = None
    fuel_efficiency_km_per_liter: Decimal | None = None
    current_odometer_km: Decimal | None = None
    last_service_date: date | None = None
    next_service_due_km: Decimal | None = None
    service_status: str = "OK"
    created_at: datetime
    updated_at: datetime
