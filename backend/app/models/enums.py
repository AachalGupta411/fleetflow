import enum

from sqlalchemy import Enum


class UserRole(str, enum.Enum):
    ADMIN = "ADMIN"
    FLEET_MANAGER = "FLEET_MANAGER"
    DRIVER = "DRIVER"
    CUSTOMER = "CUSTOMER"


class DriverStatus(str, enum.Enum):
    AVAILABLE = "AVAILABLE"
    ON_DELIVERY = "ON_DELIVERY"
    OFFLINE = "OFFLINE"
    INACTIVE = "INACTIVE"


class VehicleStatus(str, enum.Enum):
    AVAILABLE = "AVAILABLE"
    ASSIGNED = "ASSIGNED"
    IN_SERVICE = "IN_SERVICE"
    MAINTENANCE = "MAINTENANCE"
    INACTIVE = "INACTIVE"


class ShipmentPriority(str, enum.Enum):
    LOW = "LOW"
    NORMAL = "NORMAL"
    HIGH = "HIGH"
    EXPRESS = "EXPRESS"


class ShipmentStatus(str, enum.Enum):
    PENDING = "PENDING"
    ASSIGNED = "ASSIGNED"
    PICKED_UP = "PICKED_UP"
    IN_TRANSIT = "IN_TRANSIT"
    ARRIVING = "ARRIVING"
    DELIVERED = "DELIVERED"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"


user_role_enum = Enum(UserRole, name="user_role", native_enum=True)
driver_status_enum = Enum(DriverStatus, name="driver_status", native_enum=True)
vehicle_status_enum = Enum(VehicleStatus, name="vehicle_status", native_enum=True)
shipment_priority_enum = Enum(ShipmentPriority, name="shipment_priority", native_enum=True)
shipment_status_enum = Enum(ShipmentStatus, name="shipment_status", native_enum=True)

ACTIVE_SHIPMENT_STATUSES = (
    ShipmentStatus.ASSIGNED,
    ShipmentStatus.PICKED_UP,
    ShipmentStatus.IN_TRANSIT,
    ShipmentStatus.ARRIVING,
)
