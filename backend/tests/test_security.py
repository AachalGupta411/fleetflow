from datetime import UTC, datetime, timedelta

import jwt

from app.core.config import get_settings
from app.core.security import ALGORITHM
from tests.test_logistics import PASSWORD, _customer, _login


def test_invalid_and_expired_tokens_are_rejected(client, db_session):
    customer = _customer(db_session)
    missing = client.get("/api/v1/auth/me", headers={"Authorization": "Bearer not-a-jwt"})
    assert missing.status_code == 401

    expired = jwt.encode(
        {
            "sub": str(customer.id),
            "role": "CUSTOMER",
            "exp": datetime.now(UTC) - timedelta(minutes=5),
        },
        get_settings().jwt_secret,
        algorithm=ALGORITHM,
    )
    rejected = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {expired}"})
    assert rejected.status_code == 401
    assert "password" not in rejected.text

    headers = _login(client, customer.email, PASSWORD)
    current = client.get("/api/v1/auth/me", headers=headers)
    assert current.status_code == 200
    assert "password" not in current.json()
    assert "password_hash" not in current.json()


def test_customer_cannot_read_operations(client, db_session):
    headers = _login(client, _customer(db_session).email)
    assert client.get("/api/v1/operations/overview", headers=headers).status_code == 403
    assert client.get("/api/v1/analytics/drivers", headers=headers).status_code == 403
    assert client.get("/api/v1/fuel", headers=headers).status_code == 403
