from types import SimpleNamespace

import httpx

from app.core.config import get_settings
from app.services.route_service import estimate_route, normalize_address, provider

POLYLINE = "_p~iF~ps|U_ulLnnqC_mqNvxq`@"


def settings(*, google: str = "", openroute: str = "") -> SimpleNamespace:
    return SimpleNamespace(google_maps_api_key=google, openroute_api_key=openroute)


def use_settings(monkeypatch, value: SimpleNamespace) -> None:
    monkeypatch.setattr("app.services.route_service.get_settings", lambda: value)


class Response:
    def __init__(self, payload: dict, status_code: int = 200):
        self._payload = payload
        self.status_code = status_code

    @property
    def is_success(self) -> bool:
        return 200 <= self.status_code < 300

    def raise_for_status(self):
        if not self.is_success:
            raise httpx.HTTPStatusError("request failed", request=httpx.Request("GET", "https://example.test"), response=httpx.Response(self.status_code))

    def json(self):
        return self._payload


def test_route_is_unavailable_without_any_key(monkeypatch):
    use_settings(monkeypatch, settings())
    estimate = estimate_route(19.07, 72.87, 19.22, 73.08, "Dombivli")
    assert estimate.available is False
    assert estimate.eta is None
    assert estimate.distance_meters is None
    assert "API key" in (estimate.message or "")


def test_openroute_is_preferred_when_both_keys_exist():
    assert provider(settings(google="g", openroute="o")) == "openroute"
    assert provider(settings(google="g")) == "google"
    assert provider(settings()) is None


def test_google_directions_fill_distance_and_eta(monkeypatch):
    captured = {}

    def fake_get(url, params=None, timeout=None):
        captured["url"] = url
        captured["params"] = params
        return Response(
            {
                "status": "OK",
                "routes": [
                    {
                        "legs": [{"distance": {"value": 12400}, "duration": {"value": 1500}}],
                        "overview_polyline": {"points": POLYLINE},
                    }
                ],
            }
        )

    use_settings(monkeypatch, settings(google="server-key"))
    monkeypatch.setattr(httpx, "get", fake_get)
    estimate = estimate_route(18.52, 73.85, 18.62, 73.95, "Pune")
    assert captured["params"]["key"] == "server-key"
    assert "directions" in captured["url"]
    assert estimate.available is True
    assert estimate.distance_meters == 12400
    assert estimate.duration_seconds == 1500
    assert estimate.eta is not None
    assert len(estimate.points) == 3


def test_openroute_directions_send_longitude_first(monkeypatch):
    captured = {}

    def fake_post(url, headers=None, json=None, timeout=None):
        captured["url"] = url
        captured["headers"] = headers
        captured["json"] = json
        return Response(
            {
                "routes": [
                    {
                        "summary": {"distance": 12400.7, "duration": 1500.4},
                        "geometry": POLYLINE,
                    }
                ]
            }
        )

    use_settings(monkeypatch, settings(openroute="ors-key"))
    monkeypatch.setattr(httpx, "post", fake_post)
    estimate = estimate_route(19.10, 72.90, 19.20, 73.00, "Thane")
    assert captured["headers"]["Authorization"] == "ors-key"
    assert "openrouteservice" in captured["url"]
    assert captured["json"]["coordinates"] == [[72.90, 19.10], [73.00, 19.20]]
    assert estimate.available is True
    assert estimate.distance_meters == 12401
    assert estimate.duration_seconds == 1500
    assert len(estimate.points) == 3


def test_openroute_geocodes_an_address_without_coordinates(monkeypatch):
    captured = {}

    def fake_get(url, headers=None, params=None, timeout=None):
        captured["url"] = url
        captured["headers"] = headers
        captured["params"] = params
        return Response({"features": [{"geometry": {"coordinates": [72.8777, 19.0760]}}]})

    def fake_post(url, headers=None, json=None, timeout=None):
        captured["coordinates"] = json["coordinates"]
        return Response(
            {"routes": [{"summary": {"distance": 500.0, "duration": 90.0}, "geometry": POLYLINE}]}
        )

    use_settings(monkeypatch, settings(openroute="ors-key"))
    monkeypatch.setattr(httpx, "get", fake_get)
    monkeypatch.setattr(httpx, "post", fake_post)
    estimate = estimate_route(19.05, 72.85, None, None, "Chhatrapati Shivaji Terminus")
    assert captured["headers"]["Authorization"] == "ors-key"
    assert captured["params"]["text"] == "Chhatrapati Shivaji Terminus"
    assert captured["params"]["boundary.country"] == "IN"
    assert captured["params"]["focus.point.lat"] == 19.05
    assert captured["params"]["focus.point.lon"] == 72.85
    assert captured["coordinates"][1] == [72.8777, 19.0760]
    assert estimate.destination_latitude == 19.0760
    assert estimate.destination_longitude == 72.8777


def test_a_provider_outage_degrades_to_a_message(monkeypatch):
    def fake_post(url, headers=None, json=None, timeout=None):
        raise httpx.ConnectError("openrouteservice is unreachable")

    use_settings(monkeypatch, settings(openroute="ors-key"))
    monkeypatch.setattr(httpx, "post", fake_post)
    estimate = estimate_route(19.30, 72.95, 19.40, 73.05, "Vasai")
    assert estimate.available is False
    assert estimate.message == "Route lookup failed."
    assert estimate.destination_latitude == 19.40


def test_short_local_addresses_expand_before_geocoding():
    assert normalize_address("kharghat") == "Kharghar, Navi Mumbai, Maharashtra"
    assert normalize_address("Govandi") == "Govandi, Mumbai, Maharashtra"
    assert normalize_address("18 Linking Road, Mumbai, Maharashtra") == "18 Linking Road, Mumbai, Maharashtra"


def test_openroute_geocodes_the_expanded_local_address(monkeypatch):
    captured = {}

    def fake_get(url, headers=None, params=None, timeout=None):
        captured["params"] = params
        return Response({"features": [{"geometry": {"coordinates": [73.070417, 19.047302]}}]})

    def fake_post(url, headers=None, json=None, timeout=None):
        return Response({"routes": [{"summary": {"distance": 4200.0, "duration": 600.0}, "geometry": POLYLINE}]})

    use_settings(monkeypatch, settings(openroute="ors-key"))
    monkeypatch.setattr(httpx, "get", fake_get)
    monkeypatch.setattr(httpx, "post", fake_post)
    estimate = estimate_route(19.046, 73.063, None, None, "kharghat")
    assert captured["params"]["text"] == "Kharghar, Navi Mumbai, Maharashtra"
    assert estimate.available is True
    assert estimate.destination_latitude == 19.047302


def test_unroutable_destination_explains_the_address(monkeypatch):
    def fake_post(url, headers=None, json=None, timeout=None):
        return Response(
            {"error": {"code": 2010, "message": "Could not find routable point within a radius of 350.0 meters of specified coordinate 1: 67.5647600 30.0428500."}},
            status_code=404,
        )

    use_settings(monkeypatch, settings(openroute="ors-key"))
    monkeypatch.setattr(httpx, "post", fake_post)
    estimate = estimate_route(19.04, 73.06, 30.04, 67.56, "kharghat")
    assert estimate.available is False
    assert "fuller address" in (estimate.message or "")


def test_keys_are_read_and_stripped_from_the_environment(monkeypatch):
    monkeypatch.setenv("GOOGLE_MAPS_API_KEY", "  server-key  ")
    monkeypatch.setenv("OPENROUTE_API_KEY", "  ors-key  ")
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://user@localhost:5432/fleetflow")
    monkeypatch.setenv("JWT_SECRET", "test-secret-test-secret-test-secret")
    get_settings.cache_clear()
    try:
        assert get_settings().google_maps_api_key == "server-key"
        assert get_settings().openroute_api_key == "ors-key"
    finally:
        get_settings.cache_clear()
