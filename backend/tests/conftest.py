from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.db.session import engine, get_db
from app.main import app


@pytest.fixture(autouse=True)
def no_live_routing(monkeypatch):
    """Keep API tests off the live OpenRoute/Google keys in backend/.env."""
    monkeypatch.setattr(
        "app.services.route_service.get_settings",
        lambda: SimpleNamespace(google_maps_api_key="", openroute_api_key=""),
    )


@pytest.fixture
def db_session():
    connection = engine.connect()
    transaction = connection.begin()
    session = Session(bind=connection, join_transaction_mode="create_savepoint")
    try:
        yield session
    finally:
        session.close()
        transaction.rollback()
        connection.close()


@pytest.fixture
def client(db_session: Session):
    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
