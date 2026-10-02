from datetime import UTC, datetime, timedelta

from app.models.enums import UserRole
from app.models.location import Location
from app.schemas.user import UserCreate
from app.services import user_service
from app.services.freshness import classify_freshness
from tests.test_logistics import (
    PASSWORD,
    _customer,
    _driver,
    _email,
    _login,
    _manager,
    _shipment,
    _vehicle,
)


def _admin(db):
    return user_service.create_user(
        db,
        UserCreate(
            name="Avery Admin",
            email=_email("admin"),
            password=PASSWORD,
            role=UserRole.ADMIN,
        ),
    )


def _picked_up(client, db):
    customer = _customer(db)
    manager = _manager(db)
    driver = _driver(db)
    vehicle = _vehicle(db)
    customer_headers = _login(client, customer.email)
    manager_headers = _login(client, manager.email)
    driver_headers = _login(client, driver.email)
    shipment = _shipment(client, customer_headers)
    assigned = client.post(
        f"/api/v1/shipments/{shipment['id']}/assign",
        json={"driver_id": str(driver.id), "vehicle_id": str(vehicle.id)},
        headers=manager_headers,
    )
    assert assigned.status_code == 200, assigned.text
    picked = client.post(
        f"/api/v1/shipments/{shipment['id']}/status",
        json={"status": "PICKED_UP"},
        headers=driver_headers,
    )
    assert picked.status_code == 200, picked.text
    return customer, manager, driver, vehicle, picked.json(), customer_headers, manager_headers, driver_headers


def _location(latitude=19.0473, longitude=73.0699, **extra):
    body = {
        "latitude": latitude,
        "longitude": longitude,
        "accuracy": 10.5,
        "speed": 8.2,
        "heading": 120.0,
    }
    body.update(extra)
    return body


def test_driver_can_submit_own_location(client, db_session):
    _, _, driver, vehicle, _, _, _, driver_headers = _picked_up(client, db_session)
    other = _driver(db_session)
    response = client.post(
        "/api/v1/tracking/location",
        json=_location(driver_id=str(other.id)),
        headers=driver_headers,
    )
    assert response.status_code == 201, response.text
    body = response.json()
    assert body["driver_id"] == str(driver.id)
    assert body["driver_id"] != str(other.id)
    assert body["vehicle_id"] == str(vehicle.id)
    assert body["latitude"] == 19.0473
    assert body["longitude"] == 73.0699
    assert body["freshness"] == "LIVE"


def test_non_driver_cannot_submit_location(client, db_session):
    customer = _customer(db_session)
    manager = _manager(db_session)
    for user in (customer, manager):
        response = client.post(
            "/api/v1/tracking/location",
            json=_location(),
            headers=_login(client, user.email),
        )
        assert response.status_code == 403, response.text


def test_invalid_latitude_rejected(client, db_session):
    *_, driver_headers = _picked_up(client, db_session)
    response = client.post(
        "/api/v1/tracking/location",
        json=_location(latitude=91),
        headers=driver_headers,
    )
    assert response.status_code == 422, response.text


def test_invalid_longitude_rejected(client, db_session):
    *_, driver_headers = _picked_up(client, db_session)
    response = client.post(
        "/api/v1/tracking/location",
        json=_location(longitude=181),
        headers=driver_headers,
    )
    assert response.status_code == 422, response.text


def test_fleet_manager_can_view_fleet(client, db_session):
    _, manager, driver, _, shipment, _, manager_headers, driver_headers = _picked_up(client, db_session)
    posted = client.post("/api/v1/tracking/location", json=_location(), headers=driver_headers)
    assert posted.status_code == 201, posted.text
    response = client.get("/api/v1/tracking/fleet", headers=manager_headers)
    assert response.status_code == 200, response.text
    match = next(item for item in response.json() if item["driver_id"] == str(driver.id))
    assert match["tracking_number"] == shipment["tracking_number"]
    assert match["latitude"] == 19.0473
    assert "customer" not in match
    own = client.get(f"/api/v1/tracking/drivers/{driver.id}/location", headers=manager_headers)
    assert own.status_code == 200, own.text
    assert manager.role == UserRole.FLEET_MANAGER


def test_admin_can_view_fleet(client, db_session):
    admin = _admin(db_session)
    response = client.get("/api/v1/tracking/fleet", headers=_login(client, admin.email))
    assert response.status_code == 200, response.text
    assert isinstance(response.json(), list)


def test_customer_cannot_view_fleet_or_arbitrary_driver(client, db_session):
    customer, _, driver, _, _, customer_headers, _, driver_headers = _picked_up(client, db_session)
    posted = client.post("/api/v1/tracking/location", json=_location(), headers=driver_headers)
    assert posted.status_code == 201, posted.text
    fleet = client.get("/api/v1/tracking/fleet", headers=customer_headers)
    assert fleet.status_code == 403, fleet.text
    location = client.get(f"/api/v1/tracking/drivers/{driver.id}/location", headers=customer_headers)
    assert location.status_code == 403, location.text
    assert customer.role == UserRole.CUSTOMER


def test_customer_can_view_own_shipment_tracking(client, db_session):
    _, _, _, _, shipment, customer_headers, _, driver_headers = _picked_up(client, db_session)
    posted = client.post("/api/v1/tracking/location", json=_location(), headers=driver_headers)
    assert posted.status_code == 201, posted.text
    response = client.get(f"/api/v1/tracking/shipments/{shipment['id']}", headers=customer_headers)
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["tracking_number"] == shipment["tracking_number"]
    assert body["latitude"] == 19.0473
    assert body["longitude"] == 73.0699
    assert body["freshness"] == "LIVE"
    assert body["route_available"] is False
    assert body["eta"] is None
    assert "customer_name" not in body
    assert "customer_phone" not in body


def test_customer_cannot_view_another_customers_tracking(client, db_session):
    _, _, _, _, shipment, _, _, _ = _picked_up(client, db_session)
    other = _customer(db_session)
    response = client.get(
        f"/api/v1/tracking/shipments/{shipment['id']}",
        headers=_login(client, other.email),
    )
    assert response.status_code == 404, response.text


def test_fleet_returns_current_location_not_history(client, db_session):
    _, _, driver, _, _, _, manager_headers, driver_headers = _picked_up(client, db_session)
    first = client.post(
        "/api/v1/tracking/location",
        json=_location(latitude=19.01, longitude=73.01),
        headers=driver_headers,
    )
    assert first.status_code == 201, first.text
    second = client.post(
        "/api/v1/tracking/location",
        json=_location(latitude=19.22, longitude=73.22),
        headers=driver_headers,
    )
    assert second.status_code == 201, second.text
    fleet = client.get("/api/v1/tracking/fleet", headers=manager_headers)
    match = next(item for item in fleet.json() if item["driver_id"] == str(driver.id))
    assert match["latitude"] == 19.22
    assert match["longitude"] == 73.22
    current = client.get(f"/api/v1/tracking/drivers/{driver.id}/location", headers=driver_headers)
    assert current.status_code == 200, current.text
    assert current.json()["id"] == second.json()["id"]
    assert current.json()["latitude"] == 19.22


def test_stale_location_is_identified(client, db_session):
    now = datetime.now(UTC)
    assert classify_freshness(now - timedelta(seconds=10), now) == "LIVE"
    assert classify_freshness(now - timedelta(seconds=90), now) == "RECENT"
    assert classify_freshness(now - timedelta(minutes=5), now) == "STALE"
    assert classify_freshness(now - timedelta(minutes=30), now) == "OFFLINE"
    assert classify_freshness(None, now) == "OFFLINE"

    _, _, driver, _, _, _, manager_headers, driver_headers = _picked_up(client, db_session)
    posted = client.post("/api/v1/tracking/location", json=_location(), headers=driver_headers)
    assert posted.status_code == 201, posted.text
    row = db_session.get(Location, posted.json()["id"])
    row.timestamp = datetime.now(UTC) - timedelta(minutes=5)
    db_session.commit()
    response = client.get(f"/api/v1/tracking/drivers/{driver.id}/location", headers=driver_headers)
    assert response.status_code == 200, response.text
    assert response.json()["freshness"] == "STALE"
    fleet = client.get("/api/v1/tracking/fleet", headers=manager_headers)
    match = next(item for item in fleet.json() if item["driver_id"] == str(driver.id))
    assert match["freshness"] == "STALE"


def test_unassigned_driver_is_not_tracked(client, db_session):
    manager = _manager(db_session)
    driver = _driver(db_session)
    manager_headers = _login(client, manager.email)
    driver_headers = _login(client, driver.email)
    rejected = client.post("/api/v1/tracking/location", json=_location(), headers=driver_headers)
    assert rejected.status_code == 409, rejected.text
    assert "No active delivery" in rejected.json()["detail"]
    fleet = client.get("/api/v1/tracking/fleet", headers=manager_headers)
    assert all(item["driver_id"] != str(driver.id) for item in fleet.json())

    customer = _customer(db_session)
    vehicle = _vehicle(db_session)
    shipment = _shipment(client, _login(client, customer.email))
    assigned = client.post(
        f"/api/v1/shipments/{shipment['id']}/assign",
        json={"driver_id": str(driver.id), "vehicle_id": str(vehicle.id)},
        headers=manager_headers,
    )
    assert assigned.status_code == 200, assigned.text
    waiting = client.post("/api/v1/tracking/location", json=_location(), headers=driver_headers)
    assert waiting.status_code == 409, waiting.text
    assert "Start the delivery" in waiting.json()["detail"]
    fleet = client.get("/api/v1/tracking/fleet", headers=manager_headers)
    match = next(item for item in fleet.json() if item["driver_id"] == str(driver.id))
    assert match["latitude"] is None
    assert match["longitude"] is None
    assert match["freshness"] == "OFFLINE"
    assert match["status"] == "ASSIGNED"
