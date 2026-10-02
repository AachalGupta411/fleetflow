from datetime import date
from uuid import uuid4

from app.models.enums import DriverStatus, UserRole, VehicleStatus
from app.services import driver_service, user_service, vehicle_service
from app.schemas.driver import DriverCreate
from app.schemas.user import UserCreate
from app.schemas.vehicle import VehicleCreate

PASSWORD = "Testpass1"


def _email(prefix: str) -> str:
    return f"{prefix}-{uuid4().hex[:8]}@test.dev"


def _login(client, email: str, password: str = PASSWORD) -> dict[str, str]:
    response = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert response.status_code == 200, response.text
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _customer(db, email: str | None = None):
    return user_service.create_user(
        db,
        UserCreate(
            name="Casey Customer",
            email=email or _email("customer"),
            password=PASSWORD,
            role=UserRole.CUSTOMER,
        ),
    )


def _manager(db):
    return user_service.create_user(
        db,
        UserCreate(
            name="Morgan Manager",
            email=_email("manager"),
            password=PASSWORD,
            role=UserRole.FLEET_MANAGER,
        ),
    )


def _driver(db, *, status: DriverStatus = DriverStatus.AVAILABLE):
    created = driver_service.create_driver(
        db,
        DriverCreate(
            name="Devon Driver",
            email=_email("driver"),
            password=PASSWORD,
            license_number=f"LIC-{uuid4().hex[:8]}",
            license_expiry=date(2028, 6, 1),
        ),
    )
    if status != DriverStatus.AVAILABLE:
        from app.models.driver import Driver

        row = db.get(Driver, created.id)
        row.status = status
        db.commit()
    return created


def _vehicle(db, *, status: VehicleStatus = VehicleStatus.AVAILABLE):
    created = vehicle_service.create_vehicle(
        db,
        VehicleCreate(
            vehicle_number=f"MH{uuid4().hex[:6].upper()}",
            vehicle_type="Van",
            model="Tata Ace",
            capacity=750,
        ),
    )
    if status != VehicleStatus.AVAILABLE:
        from app.models.vehicle import Vehicle

        row = db.get(Vehicle, created.id)
        row.status = status
        db.commit()
    return created


def _shipment(client, headers, **overrides):
    payload = {
        "pickup_address": "Warehouse 4, Bhiwandi",
        "delivery_address": "42 Residency Road, Bengaluru",
        "package_description": "Spare parts",
        "priority": "NORMAL",
    }
    payload.update(overrides)
    response = client.post("/api/v1/shipments", json=payload, headers=headers)
    assert response.status_code == 201, response.text
    return response.json()


def test_login_success_and_current_user(client, db_session):
    customer = _customer(db_session)
    response = client.post(
        "/api/v1/auth/login",
        json={"email": customer.email, "password": PASSWORD},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    assert body["user"]["email"] == customer.email
    assert "password" not in body["user"]

    me = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {body['access_token']}"},
    )
    assert me.status_code == 200
    assert me.json()["role"] == "CUSTOMER"


def test_login_failure(client, db_session):
    customer = _customer(db_session)
    response = client.post(
        "/api/v1/auth/login",
        json={"email": customer.email, "password": "wrong-password"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid email or password"


def test_register_cannot_become_admin(client):
    response = client.post(
        "/api/v1/auth/register",
        json={
            "name": "New Customer",
            "email": _email("register"),
            "password": PASSWORD,
            "role": "ADMIN",
        },
    )
    assert response.status_code == 201
    assert response.json()["user"]["role"] == "CUSTOMER"


def test_customer_cannot_list_users(client, db_session):
    customer = _customer(db_session)
    response = client.get("/api/v1/users", headers=_login(client, customer.email))
    assert response.status_code == 403


def test_create_shipment_and_hide_it_from_other_customers(client, db_session):
    first = _customer(db_session)
    second = _customer(db_session)
    created = _shipment(client, _login(client, first.email))
    assert created["tracking_number"].startswith("FF-")
    assert created["status"] == "PENDING"
    assert created["customer_id"] == str(first.id)

    hidden = client.get(
        f"/api/v1/shipments/{created['id']}",
        headers=_login(client, second.email),
    )
    assert hidden.status_code == 404

    own_list = client.get("/api/v1/shipments", headers=_login(client, second.email))
    assert own_list.status_code == 200
    assert own_list.json() == []


def test_manager_can_list_drivers_and_vehicles(client, db_session):
    manager = _manager(db_session)
    driver = _driver(db_session)
    vehicle = _vehicle(db_session)
    headers = _login(client, manager.email)

    drivers = client.get("/api/v1/drivers", headers=headers)
    vehicles = client.get("/api/v1/vehicles", headers=headers)
    assert drivers.status_code == 200
    assert vehicles.status_code == 200
    assert any(item["id"] == str(driver.id) for item in drivers.json())
    assert any(item["id"] == str(vehicle.id) for item in vehicles.json())

    customer = _customer(db_session)
    forbidden = client.get("/api/v1/drivers", headers=_login(client, customer.email))
    assert forbidden.status_code == 403


def test_successful_assignment_updates_driver_and_vehicle(client, db_session):
    customer = _customer(db_session)
    manager = _manager(db_session)
    driver = _driver(db_session)
    vehicle = _vehicle(db_session)
    shipment = _shipment(client, _login(client, customer.email))

    assigned = client.post(
        f"/api/v1/shipments/{shipment['id']}/assign",
        json={"driver_id": str(driver.id), "vehicle_id": str(vehicle.id)},
        headers=_login(client, manager.email),
    )
    assert assigned.status_code == 200, assigned.text
    body = assigned.json()
    assert body["status"] == "ASSIGNED"
    assert body["driver_name"] == "Devon Driver"
    assert body["vehicle_number"] == vehicle.vehicle_number

    driver_row = client.get(
        f"/api/v1/drivers/{driver.id}",
        headers=_login(client, manager.email),
    ).json()
    vehicle_row = client.get(
        f"/api/v1/vehicles/{vehicle.id}",
        headers=_login(client, manager.email),
    ).json()
    assert driver_row["status"] == "ON_DELIVERY"
    assert vehicle_row["status"] == "ASSIGNED"

    driver_login = _login(client, driver.email)
    visible = client.get("/api/v1/driver/shipments", headers=driver_login)
    assert visible.status_code == 200
    assert visible.json()[0]["id"] == shipment["id"]

    picked_up = client.post(
        f"/api/v1/shipments/{shipment['id']}/status",
        json={"status": "PICKED_UP"},
        headers=driver_login,
    )
    assert picked_up.status_code == 200
    assert picked_up.json()["status"] == "PICKED_UP"

    manager_view = client.get(
        f"/api/v1/shipments/{shipment['id']}",
        headers=_login(client, manager.email),
    )
    assert manager_view.json()["status"] == "PICKED_UP"


def test_assignment_rejects_unavailable_driver_and_vehicle(client, db_session):
    customer = _customer(db_session)
    manager = _manager(db_session)
    busy_driver = _driver(db_session, status=DriverStatus.ON_DELIVERY)
    available_driver = _driver(db_session)
    busy_vehicle = _vehicle(db_session, status=VehicleStatus.ASSIGNED)
    available_vehicle = _vehicle(db_session)
    shipment = _shipment(client, _login(client, customer.email))
    headers = _login(client, manager.email)

    driver_conflict = client.post(
        f"/api/v1/shipments/{shipment['id']}/assign",
        json={"driver_id": str(busy_driver.id), "vehicle_id": str(available_vehicle.id)},
        headers=headers,
    )
    assert driver_conflict.status_code == 409
    assert "Driver" in driver_conflict.json()["detail"]

    vehicle_conflict = client.post(
        f"/api/v1/shipments/{shipment['id']}/assign",
        json={"driver_id": str(available_driver.id), "vehicle_id": str(busy_vehicle.id)},
        headers=headers,
    )
    assert vehicle_conflict.status_code == 409
    assert "Vehicle" in vehicle_conflict.json()["detail"]

    unchanged = client.get(f"/api/v1/shipments/{shipment['id']}", headers=headers)
    assert unchanged.json()["status"] == "PENDING"


def test_invalid_status_transition_is_rejected(client, db_session):
    customer = _customer(db_session)
    manager = _manager(db_session)
    driver = _driver(db_session)
    vehicle = _vehicle(db_session)
    shipment = _shipment(client, _login(client, customer.email))
    manager_headers = _login(client, manager.email)
    client.post(
        f"/api/v1/shipments/{shipment['id']}/assign",
        json={"driver_id": str(driver.id), "vehicle_id": str(vehicle.id)},
        headers=manager_headers,
    )

    skipped = client.post(
        f"/api/v1/shipments/{shipment['id']}/status",
        json={"status": "DELIVERED"},
        headers=_login(client, driver.email),
    )
    assert skipped.status_code == 409
    current = client.get(f"/api/v1/shipments/{shipment['id']}", headers=manager_headers)
    assert current.json()["status"] == "ASSIGNED"
