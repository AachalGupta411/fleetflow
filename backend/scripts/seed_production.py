

"""One-time production/demo sample data.

Refuses to run unless --confirm-dev is passed and the database host is local.
This script is not imported by the API.
"""

import argparse
import base64
import sys
from datetime import date
from decimal import Decimal
from pathlib import Path
from urllib.parse import urlparse

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from sqlalchemy import select

from app.core.config import get_settings
from app.db.session import SessionLocal
from app.models.enums import ShipmentPriority, ShipmentStatus
from app.models.user import User
from app.schemas.driver import DriverCreate
from app.models.shipment import Shipment
from app.schemas.delivery import ArrivalRequest
from app.schemas.shipment import AssignmentRequest, ShipmentCreate, StatusUpdateRequest
from app.schemas.user import UserCreate
from app.schemas.fuel import FuelCreate
from app.schemas.vehicle import VehicleCreate, VehicleUpdate
from app.services import delivery_service, driver_service, fuel_service, shipment_service, user_service, vehicle_service

DEV_PASSWORD = "Fleetflow-Dev-2026"
SEEDED_EMAIL = "admin@fleetflow.dev"


def main() -> None:
    parser = argparse.ArgumentParser(description="Load FleetFlow development sample data")
    parser.add_argument(
        "--confirm-dev",
        action="store_true",
        help="Required. Confirms this command may write development data.",
    )
    args = parser.parse_args()
    if not args.confirm_dev:
        raise SystemExit("Refusing to seed. Pass --confirm-dev explicitly.")

    settings = get_settings()

    db = SessionLocal()
    try:
        existing = db.scalar(select(User).where(User.email == SEEDED_EMAIL))
        if existing is not None:
            print("Development data already exists. Nothing was changed.")
            return

        admin = user_service.create_user(
            db,
            UserCreate(
                name="Asha Admin",
                email="admin@fleetflow.dev",
                phone="9000000001",
                password=DEV_PASSWORD,
                role="ADMIN",
            ),
        )
        manager = user_service.create_user(
            db,
            UserCreate(
                name="Manav Manager",
                email="manager@fleetflow.dev",
                phone="9000000002",
                password=DEV_PASSWORD,
                role="FLEET_MANAGER",
            ),
        )
        customer = user_service.create_user(
            db,
            UserCreate(
                name="Cara Customer",
                email="customer@fleetflow.dev",
                phone="9000000003",
                password=DEV_PASSWORD,
                role="CUSTOMER",
            ),
        )
        priya = driver_service.create_driver(
            db,
            DriverCreate(
                name="Priya Shah",
                email="driver@fleetflow.dev",
                phone="9000000004",
                password=DEV_PASSWORD,
                license_number="MH-2024-1001",
                license_expiry=date(2028, 3, 31),
            ),
        )
        kabir = driver_service.create_driver(
            db,
            DriverCreate(
                name="Kabir Rao",
                email="driver.assigned@fleetflow.dev",
                phone="9000000005",
                password=DEV_PASSWORD,
                license_number="MH-2024-1002",
                license_expiry=date(2027, 11, 30),
            ),
        )
        arjun = driver_service.create_driver(
            db,
            DriverCreate(
                name="Arjun Mehta",
                email="driver.transit@fleetflow.dev",
                phone="9000000006",
                password=DEV_PASSWORD,
                license_number="MH-2023-8841",
                license_expiry=date(2027, 8, 15),
            ),
        )
        van = vehicle_service.create_vehicle(
            db,
            VehicleCreate(
                vehicle_number="MH12AB1001",
                vehicle_type="Van",
                model="Tata Ace Gold",
                capacity=750,
            ),
        )
        truck = vehicle_service.create_vehicle(
            db,
            VehicleCreate(
                vehicle_number="MH12CD2044",
                vehicle_type="Truck",
                model="Eicher Pro 2049",
                capacity=4500,
            ),
        )
        spare = vehicle_service.create_vehicle(
            db,
            VehicleCreate(
                vehicle_number="MH01GH7781",
                vehicle_type="Van",
                model="Mahindra Supro",
                capacity=900,
            ),
        )
        vehicle_service.create_vehicle(
            db,
            VehicleCreate(
                vehicle_number="MH14EF3090",
                vehicle_type="Truck",
                model="BharatBenz 1217",
                capacity=6000,
            ),
        )
        vehicle_service.update_vehicle(
            db,
            van.id,
            VehicleUpdate(
                fuel_type="DIESEL",
                fuel_efficiency_km_per_liter=Decimal("12.50"),
                next_service_due_km=Decimal("20000.0"),
            ),
        )
        fuel_service.create_fuel(
            db,
            FuelCreate(
                vehicle_id=van.id,
                driver_id=priya.id,
                liters=Decimal("40.00"),
                price_per_liter=Decimal("95.50"),
                odometer_km=Decimal("18420.0"),
                fuel_station="Bhiwandi Fuel",
                fuel_date=date.today(),
                notes="Development fill",
            ),
        )

        customer_user = db.get(User, customer.id)
        manager_user = db.get(User, manager.id)
        priya_user = db.scalar(select(User).where(User.email == "driver@fleetflow.dev"))
        arjun_user = db.scalar(select(User).where(User.email == "driver.transit@fleetflow.dev"))

        shipment_service.create_shipment(
            db,
            customer_user,
            ShipmentCreate(
                pickup_address="FleetFlow Hub, Bhiwandi, Maharashtra",
                delivery_address="18 Linking Road, Mumbai, Maharashtra",
                package_description="Retail cartons",
                priority=ShipmentPriority.NORMAL,
            ),
        )
        delivered = shipment_service.create_shipment(
            db,
            customer_user,
            ShipmentCreate(
                pickup_address="Pune Warehouse, Pimpri, Maharashtra",
                delivery_address="221 Residency Road, Bengaluru, Karnataka",
                package_description="Electronics crates",
                priority=ShipmentPriority.HIGH,
            ),
        )
        shipment_service.assign_shipment(
            db, delivered.id, AssignmentRequest(driver_id=priya.id, vehicle_id=van.id)
        )
        _advance(db, priya_user, delivered.id, [ShipmentStatus.PICKED_UP, ShipmentStatus.IN_TRANSIT, ShipmentStatus.ARRIVING])
        _complete_sample(db, priya_user, delivered.id)

        assigned = shipment_service.create_shipment(
            db,
            customer_user,
            ShipmentCreate(
                pickup_address="Andheri Depot, Mumbai, Maharashtra",
                delivery_address="CG Road, Ahmedabad, Gujarat",
                package_description="Apparel bundles",
                priority=ShipmentPriority.EXPRESS,
            ),
        )
        shipment_service.assign_shipment(
            db, assigned.id, AssignmentRequest(driver_id=kabir.id, vehicle_id=truck.id)
        )

        moving = shipment_service.create_shipment(
            db,
            customer_user,
            ShipmentCreate(
                pickup_address="Whitefield Hub, Bengaluru, Karnataka",
                delivery_address="Park Street, Kolkata, West Bengal",
                package_description="Machine parts",
                priority=ShipmentPriority.HIGH,
            ),
        )
        shipment_service.assign_shipment(
            db, moving.id, AssignmentRequest(driver_id=arjun.id, vehicle_id=spare.id)
        )
        _advance(db, arjun_user, moving.id, [ShipmentStatus.PICKED_UP, ShipmentStatus.IN_TRANSIT])

        print("Development data loaded.")
        print(f"Password for every demo account: {DEV_PASSWORD}")
        print("admin@fleetflow.dev")
        print("manager@fleetflow.dev")
        print("customer@fleetflow.dev")
        print("driver@fleetflow.dev  (available; also completed a delivery)")
        print("driver.assigned@fleetflow.dev  (assigned shipment)")
        print("driver.transit@fleetflow.dev  (in transit)")
        print(f"Sample accounts include {admin.email} and {manager_user.email}.")
        print("Available for a new assignment: Priya Shah and vehicles MH12AB1001, MH14EF3090.")
    finally:
        db.close()


def _complete_sample(db, actor, shipment_id) -> None:
    """Finish the sample delivery with a real proof upload so the driver is released."""
    shipment = db.get(Shipment, shipment_id)
    shipment.delivery_latitude = Decimal("19.076000")
    shipment.delivery_longitude = Decimal("72.877700")
    db.commit()
    db.refresh(shipment)
    png = base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )
    delivery_service.arrive(
        db,
        actor,
        shipment.delivery.id,
        ArrivalRequest(latitude=19.0760, longitude=72.8777, client_operation_id="seed-arrive-priya-0001"),
    )
    delivery_service.submit_pod(
        db,
        actor,
        shipment.delivery.id,
        recipient_name="Sample Receiver",
        recipient_phone=None,
        notes="Development sample",
        latitude=19.0760,
        longitude=72.8777,
        accuracy=5,
        photo=png,
        photo_type="image/png",
        signature=png,
        signature_type="image/png",
        client_operation_id="seed-pod-priya-0001",
    )


def _advance(db, actor, shipment_id, statuses: list[ShipmentStatus]) -> None:
    for status in statuses:
        shipment_service.update_status(
            db,
            actor,
            shipment_id,
            StatusUpdateRequest(status=status),
        )


if __name__ == "__main__":
    main()
