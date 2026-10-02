from types import SimpleNamespace

import httpx

from app.core.config import get_settings
from app.services.route_service import estimate_route


def test_route_is_unavailable_without_a_maps_key(monkeypatch):
    monkeypatch.setattr(
        "app.services.route_service.get_settings",
        lambda: SimpleNamespace(google_maps_api_key=""),
    )
    estimate = estimate_route(19.07, 72.87, 19.22, 73.08, "Dombivli")
    assert estimate.available is False
    assert estimate.eta is None
    assert estimate.distance_meters is None
    assert "API key" in (estimate.message or "")


def test_route_returns_distance_and_eta_when_directions_succeeds(monkeypatch):
    captured = {}

    class Response:
        def raise_for_status(self):
            return None

        def json(self):
            return {
                "status": "OK",
                "routes": [
                    {
                        "legs": [
                            {
                                "distance": {"value": 12400},
                                "duration": {"value": 1500},
                            }
                        ],
                        "overview_polyline": {"points": "_p~iF~ps|U_ulLnnqC_mqNvxq`@"},
                    }
                ],
            }

    def fake_get(url, params=None, timeout=None):
        captured["url"] = url
        captured["params"] = params
        return Response()

    monkeypatch.setattr(
        "app.services.route_service.get_settings",
        lambda: SimpleNamespace(google_maps_api_key="server-key"),
    )
    monkeypatch.setattr(httpx, "get", fake_get)
    estimate = estimate_route(18.52, 73.85, 18.62, 73.95, "Pune")
    assert captured["params"]["key"] == "server-key"
    assert "directions" in captured["url"]
    assert estimate.available is True
    assert estimate.distance_meters == 12400
    assert estimate.duration_seconds == 1500
    assert estimate.eta is not None
    assert len(estimate.points) == 3


def test_maps_key_is_read_from_the_environment(monkeypatch):
    monkeypatch.setenv("GOOGLE_MAPS_API_KEY", "  server-key  ")
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://user@localhost:5432/fleetflow")
    monkeypatch.setenv("JWT_SECRET", "test-secret-test-secret-test-secret")
    get_settings.cache_clear()
    try:
        assert get_settings().google_maps_api_key == "server-key"
    finally:
        get_settings.cache_clear()
