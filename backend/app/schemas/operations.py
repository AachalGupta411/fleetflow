from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel


class FleetUtilization(BaseModel):
    total_vehicles: int
    active_vehicles: int
    available_vehicles: int
    assigned_vehicles: int
    vehicles_on_delivery: int
    inactive_vehicles: int
    total_drivers: int
    available_drivers: int
    drivers_on_delivery: int
    inactive_drivers: int
    active_deliveries: int
    completed_deliveries: int
    failed_deliveries: int
    completion_rate: float | None
    as_of: datetime


class OperationsOverview(BaseModel):
    fleet: FleetUtilization
    fuel_liters: str
    fuel_cost: str
    average_price_per_liter: str | None
    average_delivery_duration_minutes: float | None


class DriverPerformance(BaseModel):
    driver_id: UUID
    driver_name: str
    current_status: str
    assigned_deliveries: int
    completed_deliveries: int
    failed_deliveries: int
    active_delivery_count: int
    completion_rate: float | None
    failure_rate: float | None
    average_delivery_duration_minutes: float | None
    average_distance_km: float | None


class DriverActivity(BaseModel):
    delivery_id: UUID
    tracking_number: str
    shipment_status: str
    event_type: str
    created_at: datetime


class DriverOperations(BaseModel):
    driver_id: UUID
    driver_name: str
    status: str
    vehicle_id: UUID | None
    vehicle_number: str | None
    active_shipment_id: UUID | None
    active_tracking_number: str | None
    active_shipment_status: str | None
    performance: DriverPerformance
    recent_activity: list[DriverActivity]


class FleetVehicle(BaseModel):
    vehicle_id: UUID
    vehicle_number: str
    vehicle_type: str
    status: str
    fuel_type: str | None
    service_status: str
    current_odometer_km: str | None
    last_service_date: date | None
    next_service_due_km: str | None
    driver_id: UUID | None
    driver_name: str | None
    shipment_id: UUID | None
    tracking_number: str | None
    shipment_status: str | None
    latitude: float | None
    longitude: float | None
    location_recorded_at: datetime | None
    fuel_liters: str
    fuel_cost: str


class VehicleOperations(FleetVehicle):
    model: str
    fuel_efficiency_km_per_liter: str | None
    delivery_count: int
    recent_fuel: list["FuelBrief"]
    recent_events: list[DriverActivity]


class FuelBrief(BaseModel):
    id: UUID
    fuel_date: date
    liters: str
    total_cost: str
    fuel_station: str | None
    odometer_km: str | None


class BucketCount(BaseModel):
    period: str
    count: int


class BucketCost(BaseModel):
    period: str
    total_cost: str


class DeliveryAnalytics(BaseModel):
    from_date: date
    to_date: date
    bucket: str
    volume: list[BucketCount]
    completed: int
    failed: int
    active: int
    completion_rate: float | None
    average_delivery_duration_minutes: float | None


class FailureReasonCount(BaseModel):
    reason: str
    count: int


class FuelAnalytics(BaseModel):
    from_date: date
    to_date: date
    total_liters: str
    total_cost: str
    average_price_per_liter: str | None
    cost_trend: list[BucketCost]
    by_vehicle: list["FuelVehicleBrief"]


class FuelVehicleBrief(BaseModel):
    vehicle_id: UUID
    vehicle_number: str
    liters: str
    total_cost: str


VehicleOperations.model_rebuild()
FuelAnalytics.model_rebuild()
