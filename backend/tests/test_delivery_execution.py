import base64
from decimal import Decimal
from uuid import uuid4

from app.models.notification import Notification
from app.models.shipment import Shipment
from app.services.geofence import distance_meters, within_geofence
from sqlalchemy import select
from tests.test_logistics import (
    _customer,
    _driver,
    _login,
    _manager,
    _shipment,
    _vehicle,
)

PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)
DEST_LAT = 19.0760
DEST_LNG = 72.8777
NEAR_LAT = 19.0764
FAR_LAT = 19.0900


def _arriving(client, db):
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
    row = db.get(Shipment, shipment["id"])
    row.delivery_latitude = Decimal(str(DEST_LAT))
    row.delivery_longitude = Decimal(str(DEST_LNG))
    db.commit()
    for status in ("PICKED_UP", "IN_TRANSIT", "ARRIVING"):
        moved = client.post(
            f"/api/v1/shipments/{shipment['id']}/status",
            json={"status": status},
            headers=driver_headers,
        )
        assert moved.status_code == 200, moved.text
    return {
        "customer_headers": customer_headers,
        "manager_headers": manager_headers,
        "driver_headers": driver_headers,
        "other_customer_headers": _login(client, _customer(db).email),
        "other_driver_headers": _login(client, _driver(db).email),
        "shipment": moved.json(),
        "delivery_id": moved.json()["delivery_id"],
    }


def _pod_files():
    return {
        "photo": ("proof.png", PNG, "image/png"),
        "signature": ("sign.png", PNG, "image/png"),
    }


def _pod_form(operation_id: str, latitude=NEAR_LAT):
    return {
        "recipient_name": "Asha Patel",
        "latitude": str(latitude),
        "longitude": str(DEST_LNG),
        "client_operation_id": operation_id,
        "notes": "Left with recipient",
    }


def test_geofence_distance():
    assert distance_meters(DEST_LAT, DEST_LNG, DEST_LAT, DEST_LNG) == 0
    assert within_geofence(DEST_LAT, DEST_LNG, NEAR_LAT, DEST_LNG)
    assert not within_geofence(DEST_LAT, DEST_LNG, FAR_LAT, DEST_LNG)


def test_valid_arrival_records_geofence(client, db_session):
    ready = _arriving(client, db_session)
    response = client.post(
        f"/api/v1/deliveries/{ready['delivery_id']}/arrive",
        json={"latitude": NEAR_LAT, "longitude": DEST_LNG, "accuracy": 8, "client_operation_id": "arrive-valid-0001"},
        headers=ready["driver_headers"],
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["geofence_entered_at"] is not None
    events = client.get(f"/api/v1/deliveries/{ready['delivery_id']}/events", headers=ready["manager_headers"])
    assert events.status_code == 200
    assert "GEOFENCE_ENTERED" in {item["event_type"] for item in events.json()}


def test_invalid_arrival_outside_geofence(client, db_session):
    ready = _arriving(client, db_session)
    response = client.post(
        f"/api/v1/deliveries/{ready['delivery_id']}/arrive",
        json={"latitude": FAR_LAT, "longitude": DEST_LNG, "client_operation_id": "arrive-far-0001"},
        headers=ready["driver_headers"],
    )
    assert response.status_code == 422, response.text
    assert "geofence" in response.json()["detail"]


def test_other_driver_cannot_arrive(client, db_session):
    ready = _arriving(client, db_session)
    response = client.post(
        f"/api/v1/deliveries/{ready['delivery_id']}/arrive",
        json={"latitude": NEAR_LAT, "longitude": DEST_LNG},
        headers=ready["other_driver_headers"],
    )
    assert response.status_code == 404, response.text


def test_customer_cannot_submit_arrival_or_pod(client, db_session):
    ready = _arriving(client, db_session)
    arrive = client.post(
        f"/api/v1/deliveries/{ready['delivery_id']}/arrive",
        json={"latitude": NEAR_LAT, "longitude": DEST_LNG},
        headers=ready["customer_headers"],
    )
    assert arrive.status_code == 403, arrive.text
    pod = client.post(
        f"/api/v1/deliveries/{ready['delivery_id']}/pod",
        data=_pod_form("pod-customer-0001"),
        files=_pod_files(),
        headers=ready["customer_headers"],
    )
    assert pod.status_code == 403, pod.text


def test_customer_can_view_own_pod_and_not_another_customers(client, db_session):
    ready = _arriving(client, db_session)
    submitted = client.post(
        f"/api/v1/deliveries/{ready['delivery_id']}/pod",
        data=_pod_form(f"pod-{uuid4().hex[:8]}"),
        files=_pod_files(),
        headers=ready["driver_headers"],
    )
    assert submitted.status_code == 200, submitted.text
    own = client.get(f"/api/v1/deliveries/{ready['delivery_id']}/pod", headers=ready["customer_headers"])
    assert own.status_code == 200, own.text
    assert own.json()["recipient_name"] == "Asha Patel"
    photo = client.get(f"/api/v1/deliveries/{ready['delivery_id']}/pod/photo", headers=ready["customer_headers"])
    assert photo.status_code == 200
    assert photo.content.startswith(b"\x89PNG")
    hidden = client.get(f"/api/v1/deliveries/{ready['delivery_id']}/pod", headers=ready["other_customer_headers"])
    assert hidden.status_code == 404


def test_valid_pod_completes_delivery(client, db_session):
    ready = _arriving(client, db_session)
    response = client.post(
        f"/api/v1/deliveries/{ready['delivery_id']}/pod",
        data=_pod_form(f"pod-{uuid4().hex[:8]}"),
        files=_pod_files(),
        headers=ready["driver_headers"],
    )
    assert response.status_code == 200, response.text
    assert response.json()["photo_available"] is True
    assert response.json()["signature_available"] is True
    shipment = client.get(f"/api/v1/shipments/{ready['shipment']['id']}", headers=ready["customer_headers"])
    assert shipment.json()["status"] == "DELIVERED"
    assert shipment.json()["pod_available"] is True
    assert shipment.json()["recipient_name"] == "Asha Patel"


def test_missing_pod_photo_is_rejected(client, db_session):
    ready = _arriving(client, db_session)
    response = client.post(
        f"/api/v1/deliveries/{ready['delivery_id']}/pod",
        data=_pod_form(f"pod-{uuid4().hex[:8]}"),
        files={"signature": ("sign.png", PNG, "image/png")},
        headers=ready["driver_headers"],
    )
    assert response.status_code == 422, response.text


def test_missing_signature_is_rejected(client, db_session):
    ready = _arriving(client, db_session)
    response = client.post(
        f"/api/v1/deliveries/{ready['delivery_id']}/pod",
        data=_pod_form(f"pod-{uuid4().hex[:8]}"),
        files={"photo": ("proof.png", PNG, "image/png")},
        headers=ready["driver_headers"],
    )
    assert response.status_code == 422, response.text


def test_direct_delivered_transition_is_rejected(client, db_session):
    ready = _arriving(client, db_session)
    response = client.post(
        f"/api/v1/shipments/{ready['shipment']['id']}/status",
        json={"status": "DELIVERED"},
        headers=ready["driver_headers"],
    )
    assert response.status_code == 409, response.text
    assert "proof of delivery" in response.json()["detail"]


def test_failed_delivery_requires_known_reason(client, db_session):
    ready = _arriving(client, db_session)
    rejected = client.post(
        f"/api/v1/deliveries/{ready['delivery_id']}/fail",
        json={"reason": "TRAFFIC", "client_operation_id": "fail-bad-0001"},
        headers=ready["driver_headers"],
    )
    assert rejected.status_code == 422, rejected.text
    accepted = client.post(
        f"/api/v1/deliveries/{ready['delivery_id']}/fail",
        json={
            "reason": "CUSTOMER_UNAVAILABLE",
            "notes": "No answer after two calls",
            "latitude": NEAR_LAT,
            "longitude": DEST_LNG,
            "client_operation_id": "fail-good-0001",
        },
        headers=ready["driver_headers"],
    )
    assert accepted.status_code == 200, accepted.text
    assert accepted.json()["failure_code"] == "CUSTOMER_UNAVAILABLE"
    shipment = client.get(f"/api/v1/shipments/{ready['shipment']['id']}", headers=ready["manager_headers"])
    assert shipment.json()["status"] == "FAILED"
    events = client.get("/api/v1/deliveries/events/recent", headers=ready["manager_headers"])
    assert any(item["event_type"] == "FAILED" for item in events.json())


def test_duplicate_pod_submission_is_idempotent(client, db_session):
    ready = _arriving(client, db_session)
    operation = f"pod-{uuid4().hex[:8]}"
    first = client.post(
        f"/api/v1/deliveries/{ready['delivery_id']}/pod",
        data=_pod_form(operation),
        files=_pod_files(),
        headers=ready["driver_headers"],
    )
    assert first.status_code == 200, first.text
    second = client.post(
        f"/api/v1/deliveries/{ready['delivery_id']}/pod",
        data=_pod_form(operation),
        files=_pod_files(),
        headers=ready["driver_headers"],
    )
    assert second.status_code == 200, second.text
    assert second.json()["duplicate"] is True


def test_sync_applies_once(client, db_session):
    ready = _arriving(client, db_session)
    action = {
        "client_operation_id": "sync-fail-0001",
        "delivery_id": ready["delivery_id"],
        "action": "FAIL",
        "payload": {"reason": "ACCESS_ISSUE", "notes": "Gate locked"},
    }
    first = client.post("/api/v1/sync/delivery-actions", json={"actions": [action]}, headers=ready["driver_headers"])
    assert first.status_code == 200, first.text
    assert first.json()["results"][0]["status"] == "applied"
    second = client.post("/api/v1/sync/delivery-actions", json={"actions": [action]}, headers=ready["driver_headers"])
    assert second.status_code == 200, second.text
    assert second.json()["results"][0]["status"] == "duplicate"
    customer_sync = client.post(
        "/api/v1/sync/delivery-actions",
        json={"actions": [action | {"client_operation_id": "sync-customer-01"}]},
        headers=ready["customer_headers"],
    )
    assert customer_sync.status_code == 403


def test_device_token_and_assignment_notification(client, db_session):
    ready = _arriving(client, db_session)
    registered = client.post(
        "/api/v1/notifications/device-token",
        json={"token": "fcm-test-token-123456", "platform": "android"},
        headers=ready["customer_headers"],
    )
    assert registered.status_code == 204, registered.text
    removed = client.request(
        "DELETE",
        "/api/v1/notifications/device-token",
        json={"token": "fcm-test-token-123456", "platform": "android"},
        headers=ready["customer_headers"],
    )
    assert removed.status_code == 204, removed.text
    notes = client.get("/api/v1/notifications", headers=ready["customer_headers"])
    assert notes.status_code == 200, notes.text
    kinds = {item["kind"] for item in notes.json()}
    assert "SHIPMENT_ASSIGNED" in kinds
    assert "SHIPMENT_PICKED_UP" in kinds
    assert all(item["push_sent"] is False for item in notes.json())
    stored = db_session.scalars(select(Notification).where(Notification.kind == "SHIPMENT_ASSIGNED")).all()
    assert stored
