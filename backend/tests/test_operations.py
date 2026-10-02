from datetime import UTC, datetime
from decimal import Decimal
from uuid import uuid4

from app.models.delivery import Delivery
from app.models.location import Location
from app.models.shipment import Shipment
from app.services.metrics import delivery_duration_minutes, outcome_rates
from tests.test_delivery_execution import _pod_files, _pod_form
from tests.test_logistics import _customer, _driver, _login, _manager, _shipment, _vehicle

DEST_LAT = Decimal("19.0760")
DEST_LNG = Decimal("72.8777")


def test_duration_uses_only_recorded_timestamps():
    start = datetime(2026, 9, 1, 10, 0, tzinfo=UTC)
    end = datetime(2026, 9, 1, 10, 42, tzinfo=UTC)
    assert delivery_duration_minutes(start, end) == 42
    assert delivery_duration_minutes(None, end) is None
    assert delivery_duration_minutes(end, start) is None
    assert outcome_rates(8, 2) == (0.8, 0.2)
    assert outcome_rates(0, 0) == (None, None)


def test_fuel_record_summary_and_authorization(client, db_session):
    manager = _login(client, _manager(db_session).email)
    customer = _login(client, _customer(db_session).email)
    driver = _driver(db_session)
    driver_headers = _login(client, driver.email)
    vehicle = _vehicle(db_session)
    other = _vehicle(db_session)

    denied = client.post(
        "/api/v1/fuel",
        json=_fuel_body(vehicle.id),
        headers=customer,
    )
    assert denied.status_code == 403
    assert client.get("/api/v1/fuel", headers=driver_headers).status_code == 403
    assert client.get("/api/v1/analytics/overview", headers=customer).status_code == 403
    assert client.get("/api/v1/operations/drivers", headers=driver_headers).status_code == 403

    invalid = client.post(
        "/api/v1/fuel",
        json=_fuel_body(vehicle.id, liters="0"),
        headers=manager,
    )
    assert invalid.status_code == 422
    invalid_price = client.post(
        "/api/v1/fuel",
        json=_fuel_body(vehicle.id, price="0"),
        headers=manager,
    )
    assert invalid_price.status_code == 422
    missing = client.post(
        "/api/v1/fuel",
        json=_fuel_body(uuid4()),
        headers=manager,
    )
    assert missing.status_code == 404

    created = client.post("/api/v1/fuel", json=_fuel_body(vehicle.id, driver_id=driver.id), headers=manager)
    assert created.status_code == 201, created.text
    body = created.json()
    assert body["total_cost"] == "1000.00"
    assert body["liters"] == "10.00"
    assert body["vehicle_number"] == vehicle.vehicle_number

    backwards = client.post(
        "/api/v1/fuel",
        json=_fuel_body(vehicle.id, odometer="1000.0"),
        headers=manager,
    )
    assert backwards.status_code == 409

    listed = client.get(f"/api/v1/fuel?vehicle_id={vehicle.id}", headers=manager)
    assert listed.status_code == 200
    assert len(listed.json()) == 1
    other_list = client.get(f"/api/v1/fuel/vehicles/{other.id}", headers=manager)
    assert other_list.status_code == 200
    assert other_list.json() == []

    summary = client.get(f"/api/v1/fuel/summary?vehicle_id={vehicle.id}", headers=manager)
    assert summary.status_code == 200
    assert summary.json()["total_liters"] == "10.00"
    assert summary.json()["total_cost"] == "1000.00"
    assert summary.json()["average_price_per_liter"] == "100.00"
    assert summary.json()["by_vehicle"][0]["vehicle_number"] == vehicle.vehicle_number

    one = client.get(f"/api/v1/fuel/{body['id']}", headers=manager)
    assert one.status_code == 200
    assert client.get(f"/api/v1/fuel/{uuid4()}", headers=manager).status_code == 404


def test_driver_performance_and_empty_driver(client, db_session):
    customer = _customer(db_session)
    manager_headers = _login(client, _manager(db_session).email)
    driver = _driver(db_session)
    driver_headers = _login(client, driver.email)
    vehicle = _vehicle(db_session)
    customer_headers = _login(client, customer.email)

    delivered = _finish_delivery(client, db_session, customer_headers, manager_headers, driver, vehicle, driver_headers)
    db_session.expire_all()
    row = db_session.get(Delivery, delivered["delivery_id"])
    db_session.add(
        Location(
            driver_id=driver.id,
            vehicle_id=vehicle.id,
            latitude=19.0761,
            longitude=72.8777,
            timestamp=row.picked_up_at,
        )
    )
    db_session.add(
        Location(
            driver_id=driver.id,
            vehicle_id=vehicle.id,
            latitude=19.0770,
            longitude=72.8777,
            timestamp=row.delivered_at,
        )
    )
    db_session.commit()

    second = _shipment(client, customer_headers)
    assigned = client.post(
        f"/api/v1/shipments/{second['id']}/assign",
        json={"driver_id": str(driver.id), "vehicle_id": str(vehicle.id)},
        headers=manager_headers,
    )
    assert assigned.status_code == 200, assigned.text
    for status in ("PICKED_UP", "IN_TRANSIT"):
        moved = client.post(
            f"/api/v1/shipments/{second['id']}/status",
            json={"status": status},
            headers=driver_headers,
        )
        assert moved.status_code == 200, moved.text
    failed = client.post(
        f"/api/v1/deliveries/{second['delivery_id']}/fail",
        json={"reason": "CUSTOMER_UNAVAILABLE", "notes": "No answer", "client_operation_id": f"ops-fail-{uuid4().hex[:8]}"},
        headers=driver_headers,
    )
    assert failed.status_code == 200, failed.text

    performance = client.get(f"/api/v1/operations/drivers/{driver.id}/performance", headers=manager_headers)
    assert performance.status_code == 200, performance.text
    metrics = performance.json()
    assert metrics["completed_deliveries"] == 1
    assert metrics["failed_deliveries"] == 1
    assert metrics["completion_rate"] == 0.5
    assert metrics["failure_rate"] == 0.5
    assert metrics["average_delivery_duration_minutes"] is not None
    assert metrics["average_distance_km"] is not None

    detail = client.get(f"/api/v1/operations/drivers/{driver.id}", headers=manager_headers)
    assert detail.status_code == 200
    assert any(item["event_type"] == "DELIVERED" for item in detail.json()["recent_activity"])
    assert detail.json()["driver_name"] == driver.name

    idle = _driver(db_session)
    empty = client.get(f"/api/v1/operations/drivers/{idle.id}/performance", headers=manager_headers)
    assert empty.status_code == 200
    empty_body = empty.json()
    assert empty_body["assigned_deliveries"] == 0
    assert empty_body["completion_rate"] is None
    assert empty_body["average_delivery_duration_minutes"] is None
    assert empty_body["average_distance_km"] is None
    assert client.get(f"/api/v1/operations/drivers/{uuid4()}", headers=manager_headers).status_code == 404


def test_fleet_utilization_counts_change_with_new_records(client, db_session):
    manager = _login(client, _manager(db_session).email)
    before = client.get("/api/v1/analytics/fleet-utilization", headers=manager)
    assert before.status_code == 200, before.text
    _vehicle(db_session)
    _driver(db_session)
    after = client.get("/api/v1/operations/utilization", headers=manager)
    assert after.json()["total_vehicles"] == before.json()["total_vehicles"] + 1
    assert after.json()["available_vehicles"] == before.json()["available_vehicles"] + 1
    assert after.json()["total_drivers"] == before.json()["total_drivers"] + 1
    assert after.json()["available_drivers"] == before.json()["available_drivers"] + 1
    assert "active_deliveries" in after.json()


def test_analytics_filters_and_empty_range(client, db_session):
    manager = _login(client, _manager(db_session).email)
    vehicle = _vehicle(db_session)
    today = datetime.now(UTC).date().isoformat()
    created = client.post(
        "/api/v1/fuel",
        json=_fuel_body(vehicle.id, fuel_date=today),
        headers=manager,
    )
    assert created.status_code == 201, created.text

    bad = client.get("/api/v1/analytics/deliveries?from=2026-09-10&to=2026-09-01", headers=manager)
    assert bad.status_code == 400
    partial = client.get("/api/v1/analytics/fuel?from=2026-09-01", headers=manager)
    assert partial.status_code == 400

    empty = client.get("/api/v1/analytics/deliveries?from=2000-01-01&to=2000-01-07", headers=manager)
    assert empty.status_code == 200
    assert empty.json()["volume"] == []
    assert empty.json()["completed"] == 0
    assert empty.json()["failed"] == 0
    assert empty.json()["completion_rate"] is None
    assert empty.json()["average_delivery_duration_minutes"] is None

    reasons = client.get("/api/v1/analytics/failure-reasons?from=2000-01-01&to=2000-01-07", headers=manager)
    assert reasons.status_code == 200
    assert reasons.json() == []

    before_fuel = client.get(f"/api/v1/analytics/fuel?from={today}&to={today}", headers=manager)
    created = client.post(
        "/api/v1/fuel",
        json=_fuel_body(vehicle.id, fuel_date=today, odometer="16000.0"),
        headers=manager,
    )
    assert created.status_code == 201, created.text
    fuel = client.get(f"/api/v1/analytics/fuel?from={today}&to={today}", headers=manager)
    assert fuel.status_code == 200
    before_cost = Decimal(before_fuel.json()["total_cost"])
    assert Decimal(fuel.json()["total_cost"]) - before_cost == Decimal("1000.00")
    match = next(item for item in fuel.json()["by_vehicle"] if item["vehicle_id"] == str(vehicle.id))
    assert match["total_cost"] == "2000.00"
    assert fuel.json()["cost_trend"]

    old = client.get("/api/v1/analytics/fuel?from=2000-01-01&to=2000-01-02", headers=manager)
    assert old.json()["total_liters"] == "0.00"
    assert old.json()["by_vehicle"] == []

    outcomes = client.get("/api/v1/analytics/deliveries", headers=manager)
    assert outcomes.status_code == 200
    assert "active" in outcomes.json()


def _fuel_body(vehicle_id, liters="10.00", price="100.00", odometer="15000.0", driver_id=None, fuel_date="2026-09-29"):
    body = {
        "vehicle_id": str(vehicle_id),
        "liters": liters,
        "price_per_liter": price,
        "odometer_km": odometer,
        "fuel_station": "Test Pump",
        "fuel_date": fuel_date,
        "notes": "Test fill",
    }
    if driver_id is not None:
        body["driver_id"] = str(driver_id)
    return body


def _finish_delivery(client, db, customer_headers, manager_headers, driver, vehicle, driver_headers):
    shipment = _shipment(client, customer_headers)
    assigned = client.post(
        f"/api/v1/shipments/{shipment['id']}/assign",
        json={"driver_id": str(driver.id), "vehicle_id": str(vehicle.id)},
        headers=manager_headers,
    )
    assert assigned.status_code == 200, assigned.text
    row = db.get(Shipment, shipment["id"])
    row.delivery_latitude = DEST_LAT
    row.delivery_longitude = DEST_LNG
    db.commit()
    for status in ("PICKED_UP", "IN_TRANSIT", "ARRIVING"):
        moved = client.post(
            f"/api/v1/shipments/{shipment['id']}/status",
            json={"status": status},
            headers=driver_headers,
        )
        assert moved.status_code == 200, moved.text
    proof = client.post(
        f"/api/v1/deliveries/{moved.json()['delivery_id']}/pod",
        data=_pod_form(f"ops-pod-{uuid4().hex[:8]}"),
        files=_pod_files(),
        headers=driver_headers,
    )
    assert proof.status_code == 200, proof.text
    return moved.json()
