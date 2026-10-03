from datetime import UTC, datetime, timedelta
from threading import Lock

import httpx

from app.core.config import Settings, get_settings

_cache: dict[tuple, tuple[datetime, "RouteEstimate"]] = {}
_cache_lock = Lock()
_CACHE_TTL = timedelta(seconds=60)

GOOGLE = "google"
OPENROUTE = "openroute"

_GOOGLE_DIRECTIONS_URL = "https://maps.googleapis.com/maps/api/directions/json"
_GOOGLE_GEOCODE_URL = "https://maps.googleapis.com/maps/api/geocode/json"
_OPENROUTE_DIRECTIONS_URL = "https://api.openrouteservice.org/v2/directions/driving-car"
_OPENROUTE_GEOCODE_URL = "https://api.openrouteservice.org/geocode/search"

NO_PROVIDER_MESSAGE = "Route and ETA need a routing API key on the server."

# Short local names used in this fleet. Without these, "kharghat" resolves to Pakistan.
_LOCAL_ADDRESSES = {
    "kharghat": "Kharghar, Navi Mumbai, Maharashtra",
    "kharghar": "Kharghar, Navi Mumbai, Maharashtra",
    "govandi": "Govandi, Mumbai, Maharashtra",
    "ulwe": "Ulwe, Navi Mumbai, Maharashtra",
    "sion": "Sion, Mumbai, Maharashtra",
    "dombilvali": "Dombivli, Maharashtra",
    "dombivli": "Dombivli, Maharashtra",
    "thane hiranandani": "Hiranandani Estate, Thane, Maharashtra",
    "regency garden": "Regency Garden, Navi Mumbai, Maharashtra",
}


class RouteEstimate:
    def __init__(
        self,
        *,
        available: bool,
        message: str | None = None,
        distance_meters: int | None = None,
        duration_seconds: int | None = None,
        eta: datetime | None = None,
        points: list[tuple[float, float]] | None = None,
        destination_latitude: float | None = None,
        destination_longitude: float | None = None,
    ) -> None:
        self.available = available
        self.message = message
        self.distance_meters = distance_meters
        self.duration_seconds = duration_seconds
        self.eta = eta
        self.points = points or []
        self.destination_latitude = destination_latitude
        self.destination_longitude = destination_longitude

    @classmethod
    def unavailable(cls, message: str, *, latitude: float | None = None, longitude: float | None = None):
        return cls(
            available=False,
            message=message,
            destination_latitude=latitude,
            destination_longitude=longitude,
        )


def provider(settings: Settings | None = None) -> str | None:
    """OpenRouteService wins when both keys are set, because it costs nothing."""
    settings = settings or get_settings()
    if settings.openroute_api_key:
        return OPENROUTE
    if settings.google_maps_api_key:
        return GOOGLE
    return None


def routes_configured() -> bool:
    return provider() is not None


def estimate_route(
    origin_latitude: float | None,
    origin_longitude: float | None,
    destination_latitude: float | None,
    destination_longitude: float | None,
    destination_address: str,
) -> RouteEstimate:
    if origin_latitude is None or origin_longitude is None:
        return RouteEstimate.unavailable(
            "Driver location is currently unavailable.",
            latitude=destination_latitude,
            longitude=destination_longitude,
        )
    settings = get_settings()
    chosen = provider(settings)
    if chosen is None:
        return RouteEstimate.unavailable(
            NO_PROVIDER_MESSAGE,
            latitude=destination_latitude,
            longitude=destination_longitude,
        )

    cache_key = (
        chosen,
        round(origin_latitude, 3),
        round(origin_longitude, 3),
        None if destination_latitude is None else round(destination_latitude, 3),
        None if destination_longitude is None else round(destination_longitude, 3),
        destination_address.strip().lower(),
    )
    cached = _cached(cache_key)
    if cached is not None:
        return cached

    try:
        dest_lat, dest_lng = _destination(
            settings,
            chosen,
            destination_latitude,
            destination_longitude,
            destination_address,
            focus_latitude=origin_latitude,
            focus_longitude=origin_longitude,
        )
        estimate = _directions(
            settings,
            chosen,
            origin_latitude,
            origin_longitude,
            dest_lat,
            dest_lng,
        )
    except (RouteLookupError, httpx.HTTPError, KeyError, IndexError, ValueError, TypeError) as exc:
        message = str(exc) if isinstance(exc, RouteLookupError) else "Route lookup failed."
        estimate = RouteEstimate.unavailable(
            message,
            latitude=destination_latitude,
            longitude=destination_longitude,
        )
    if estimate.available:
        _store(cache_key, estimate)
    return estimate


class RouteLookupError(Exception):
    pass


def _raise_for_provider(response: httpx.Response) -> None:
    if response.is_success:
        return
    payload: dict = {}
    try:
        parsed = response.json()
        if isinstance(parsed, dict):
            payload = parsed
    except ValueError:
        payload = {}
    error = payload.get("error")
    message = None
    if isinstance(error, dict):
        message = error.get("message")
    elif isinstance(error, str):
        message = error
    if message and "routable point" in message.lower():
        raise RouteLookupError(
            "No driving route is available for this delivery. Use a fuller address or add coordinates."
        )
    if message:
        raise RouteLookupError(message)
    raise RouteLookupError("Route lookup failed.")


def resolve_destination(latitude: float | None, longitude: float | None, address: str) -> tuple[float, float]:
    if latitude is not None and longitude is not None:
        return float(latitude), float(longitude)
    settings = get_settings()
    chosen = provider(settings)
    if chosen is None:
        raise RouteLookupError(
            "Delivery coordinates are not available. Add them to the shipment or configure geocoding."
        )
    return _destination(settings, chosen, None, None, address)


def _destination(
    settings: Settings,
    chosen: str,
    latitude: float | None,
    longitude: float | None,
    address: str,
    focus_latitude: float | None = None,
    focus_longitude: float | None = None,
) -> tuple[float, float]:
    if latitude is not None and longitude is not None:
        return latitude, longitude
    if not address.strip():
        raise RouteLookupError("This shipment has no delivery coordinates.")
    query = normalize_address(address)
    if chosen == OPENROUTE:
        return _openroute_geocode(
            settings.openroute_api_key,
            query,
            focus_latitude=focus_latitude,
            focus_longitude=focus_longitude,
        )
    return _google_geocode(settings.google_maps_api_key, query)


def normalize_address(address: str) -> str:
    cleaned = " ".join(address.split()).strip(" ,")
    alias = _LOCAL_ADDRESSES.get(cleaned.casefold())
    if alias is not None:
        return alias
    return cleaned


def _directions(
    settings: Settings,
    chosen: str,
    origin_latitude: float,
    origin_longitude: float,
    destination_latitude: float,
    destination_longitude: float,
) -> RouteEstimate:
    if chosen == OPENROUTE:
        return _openroute_directions(
            settings.openroute_api_key,
            origin_latitude,
            origin_longitude,
            destination_latitude,
            destination_longitude,
        )
    return _google_directions(
        settings.google_maps_api_key,
        origin_latitude,
        origin_longitude,
        destination_latitude,
        destination_longitude,
    )


def _google_geocode(api_key: str, address: str) -> tuple[float, float]:
    response = httpx.get(
        _GOOGLE_GEOCODE_URL,
        params={"address": address, "key": api_key, "region": "in"},
        timeout=8,
    )
    response.raise_for_status()
    payload = response.json()
    results = payload.get("results") or []
    if payload.get("status") != "OK" or not results:
        raise RouteLookupError("The delivery address could not be located.")
    location = results[0]["geometry"]["location"]
    return float(location["lat"]), float(location["lng"])


def _google_directions(
    api_key: str,
    origin_latitude: float,
    origin_longitude: float,
    destination_latitude: float,
    destination_longitude: float,
) -> RouteEstimate:
    response = httpx.get(
        _GOOGLE_DIRECTIONS_URL,
        params={
            "origin": f"{origin_latitude},{origin_longitude}",
            "destination": f"{destination_latitude},{destination_longitude}",
            "key": api_key,
        },
        timeout=8,
    )
    _raise_for_provider(response)
    payload = response.json()
    routes = payload.get("routes") or []
    if payload.get("status") != "OK" or not routes:
        raise RouteLookupError("No driving route is available for this delivery.")
    leg = routes[0]["legs"][0]
    return _estimate(
        distance_meters=int(leg["distance"]["value"]),
        duration_seconds=int(leg["duration"]["value"]),
        encoded=routes[0].get("overview_polyline", {}).get("points", ""),
        destination_latitude=destination_latitude,
        destination_longitude=destination_longitude,
    )


def _openroute_geocode(
    api_key: str,
    address: str,
    *,
    focus_latitude: float | None = None,
    focus_longitude: float | None = None,
) -> tuple[float, float]:
    """Pelias returns GeoJSON, so coordinates arrive as [longitude, latitude]."""
    params: dict[str, object] = {"text": address, "size": 1, "boundary.country": "IN"}
    if focus_latitude is not None and focus_longitude is not None:
        params["focus.point.lat"] = focus_latitude
        params["focus.point.lon"] = focus_longitude
    response = httpx.get(
        _OPENROUTE_GEOCODE_URL,
        headers={"Authorization": api_key},
        params=params,
        timeout=8,
    )
    _raise_for_provider(response)
    features = response.json().get("features") or []
    if not features:
        raise RouteLookupError("The delivery address could not be located. Use a fuller address or add coordinates.")
    longitude, latitude = features[0]["geometry"]["coordinates"][:2]
    return float(latitude), float(longitude)


def _openroute_directions(
    api_key: str,
    origin_latitude: float,
    origin_longitude: float,
    destination_latitude: float,
    destination_longitude: float,
) -> RouteEstimate:
    """OpenRouteService takes longitude first and returns a precision-5 polyline."""
    response = httpx.post(
        _OPENROUTE_DIRECTIONS_URL,
        headers={"Authorization": api_key, "Content-Type": "application/json"},
        json={
            "coordinates": [
                [origin_longitude, origin_latitude],
                [destination_longitude, destination_latitude],
            ]
        },
        timeout=8,
    )
    _raise_for_provider(response)
    routes = response.json().get("routes") or []
    if not routes:
        raise RouteLookupError("No driving route is available for this delivery.")
    summary = routes[0].get("summary") or {}
    if "distance" not in summary or "duration" not in summary:
        raise RouteLookupError("No driving route is available for this delivery.")
    return _estimate(
        distance_meters=int(round(float(summary["distance"]))),
        duration_seconds=int(round(float(summary["duration"]))),
        encoded=routes[0].get("geometry") or "",
        destination_latitude=destination_latitude,
        destination_longitude=destination_longitude,
    )


def _estimate(
    *,
    distance_meters: int,
    duration_seconds: int,
    encoded: str,
    destination_latitude: float,
    destination_longitude: float,
) -> RouteEstimate:
    return RouteEstimate(
        available=True,
        distance_meters=distance_meters,
        duration_seconds=duration_seconds,
        eta=datetime.now(UTC) + timedelta(seconds=duration_seconds),
        points=_decode_polyline(encoded),
        destination_latitude=destination_latitude,
        destination_longitude=destination_longitude,
    )


def _decode_polyline(encoded: str) -> list[tuple[float, float]]:
    points: list[tuple[float, float]] = []
    index = 0
    latitude = 0
    longitude = 0
    length = len(encoded)
    while index < length:
        latitude_change, index = _decode_chunk(encoded, index)
        longitude_change, index = _decode_chunk(encoded, index)
        latitude += latitude_change
        longitude += longitude_change
        points.append((latitude / 1e5, longitude / 1e5))
    return points


def _decode_chunk(encoded: str, index: int) -> tuple[int, int]:
    result = 0
    shift = 0
    while True:
        chunk = ord(encoded[index]) - 63
        index += 1
        result |= (chunk & 0x1F) << shift
        shift += 5
        if chunk < 0x20:
            break
    delta = ~(result >> 1) if result & 1 else result >> 1
    return delta, index


def _cached(key: tuple) -> RouteEstimate | None:
    with _cache_lock:
        found = _cache.get(key)
    if found is None:
        return None
    stored_at, estimate = found
    if datetime.now(UTC) - stored_at > _CACHE_TTL:
        return None
    return estimate


def _store(key: tuple, estimate: RouteEstimate) -> None:
    with _cache_lock:
        _cache[key] = (datetime.now(UTC), estimate)
