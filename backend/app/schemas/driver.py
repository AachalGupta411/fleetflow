from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.models.enums import DriverStatus


class DriverCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    phone: str | None = Field(default=None, max_length=20)
    password: str = Field(min_length=8, max_length=72)
    license_number: str = Field(min_length=3, max_length=40)
    license_expiry: date


class DriverUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    phone: str | None = Field(default=None, max_length=20)
    license_number: str | None = Field(default=None, min_length=3, max_length=40)
    license_expiry: date | None = None
    status: DriverStatus | None = None


class DriverRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    name: str
    email: EmailStr
    phone: str | None
    license_number: str
    license_expiry: date
    status: DriverStatus
    is_active: bool
    created_at: datetime
    updated_at: datetime
