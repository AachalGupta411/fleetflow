from datetime import date, datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field, field_serializer

FUEL_TYPES = ("PETROL", "DIESEL", "CNG", "ELECTRIC")


class FuelCreate(BaseModel):
    vehicle_id: UUID
    driver_id: UUID | None = None
    liters: Decimal = Field(gt=0, le=Decimal("10000"), max_digits=10, decimal_places=2)
    price_per_liter: Decimal = Field(gt=0, le=Decimal("10000"), max_digits=10, decimal_places=2)
    odometer_km: Decimal | None = Field(default=None, ge=0, le=Decimal("9999999.9"))
    fuel_station: str | None = Field(default=None, max_length=120)
    fuel_date: date
    notes: str | None = Field(default=None, max_length=500)


class FuelRead(BaseModel):
    id: UUID
    vehicle_id: UUID
    vehicle_number: str
    driver_id: UUID | None
    driver_name: str | None
    liters: Decimal
    price_per_liter: Decimal
    total_cost: Decimal
    odometer_km: Decimal | None
    fuel_station: str | None
    fuel_date: date
    notes: str | None
    created_at: datetime

    @field_serializer("liters", "price_per_liter", "total_cost")
    def _money(self, value: Decimal) -> str:
        return format(value.quantize(Decimal("0.01")), "f")

    @field_serializer("odometer_km")
    def _odo(self, value: Decimal | None) -> str | None:
        if value is None:
            return None
        return format(value.quantize(Decimal("0.1")), "f")


class FuelVehicleTotal(BaseModel):
    vehicle_id: UUID
    vehicle_number: str
    liters: Decimal
    total_cost: Decimal

    @field_serializer("liters", "total_cost")
    def _money(self, value: Decimal) -> str:
        return format(value.quantize(Decimal("0.01")), "f")


class FuelSummary(BaseModel):
    total_liters: Decimal
    total_cost: Decimal
    average_price_per_liter: Decimal | None
    by_vehicle: list[FuelVehicleTotal]

    @field_serializer("total_liters", "total_cost")
    def _money(self, value: Decimal) -> str:
        return format(value.quantize(Decimal("0.01")), "f")

    @field_serializer("average_price_per_liter")
    def _avg(self, value: Decimal | None) -> str | None:
        if value is None:
            return None
        return format(value.quantize(Decimal("0.01")), "f")
