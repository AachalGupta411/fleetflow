from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.services.health import database_is_connected

client = TestClient(app)


def test_root_reports_running_api() -> None:
    response = client.get("/")

    assert response.status_code == 200
    assert response.json() == {
        "message": "FleetFlow API is running",
        "docs": "/docs",
    }


def test_health_reports_connected_database() -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "FleetFlow API",
        "database": "connected",
    }


def test_health_does_not_report_ok_when_check_fails(monkeypatch) -> None:
    monkeypatch.setattr(
        "app.api.routes.health.database_is_connected",
        lambda db: False,
    )

    response = client.get("/health")

    assert response.status_code == 503
    body = response.json()
    assert body["status"] == "unavailable"
    assert body["database"] == "disconnected"
    assert body["status"] != "ok"


def test_database_check_is_false_when_postgres_is_unreachable() -> None:
    engine = create_engine(
        "postgresql+psycopg://invalid:invalid@127.0.0.1:1/fleetflow",
        connect_args={"connect_timeout": 2},
    )
    session = sessionmaker(bind=engine)()
    try:
        assert database_is_connected(session) is False
    finally:
        session.close()
        engine.dispose()
