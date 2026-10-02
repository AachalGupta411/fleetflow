"""ORM models registered for Alembic and the API."""

from app.models.delivery import Delivery
from app.models.delivery_event import DeliveryEvent
from app.models.delivery_operation import DeliveryOperation
from app.models.device_token import DeviceToken
from app.models.driver import Driver
from app.models.fuel_record import FuelRecord
from app.models.location import Location
from app.models.notification import Notification
from app.models.shipment import Shipment
from app.models.user import User
from app.models.vehicle import Vehicle

__all__ = [
    "User",
    "Driver",
    "Vehicle",
    "Shipment",
    "Delivery",
    "Location",
    "DeliveryEvent",
    "DeliveryOperation",
    "DeviceToken",
    "Notification",
    "FuelRecord",
]
