from datetime import UTC, datetime, timedelta
from threading import Lock

import httpx

from app.core.config import get_settings

_cache: dict[tuple, tuple[datetime, "RouteEstimate"]] = {}
_cache_lock = Lock()
_CACHE_TTL = timedelta(seconds=60)


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
    if not settings.google_maps_api_key:
        return RouteEstimate.unavailable(
            "Route and ETA need a Google Maps API key on the server.",
            latitude=destination_latitude,
            longitude=destination_longitude,
        )

    cache_key = (
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
            settings.google_maps_api_key,
            destination_latitude,
            destination_longitude,
            destination_address,
        )
        estimate = _directions(
            settings.google_maps_api_key,
            origin_latitude,
            origin_longitude,
            dest_lat,
            dest_lng,
        )
    except (RouteLookupError, httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
        message = str(exc) if isinstance(exc, RouteLookupError) else "Route lookup failed."
        estimate = RouteEstimate.unavailable(
            message,
            latitude=destination_latitude,
            longitude=destination_longitude,
        )
    _store(cache_key, estimate)
    return estimate


class RouteLookupError(Exception):
    pass


def resolve_destination(latitude: float | None, longitude: float | None, address: str) -> tuple[float, float]:
    if latitude is not None and longitude is not None:
        return float(latitude), float(longitude)
    settings = get_settings()
    if not settings.google_maps_api_key:
        raise RouteLookupError(
            "Delivery coordinates are not available. Add them to the shipment or configure geocoding."
        )
    return _destination(settings.google_maps_api_key, None, None, address)


def _destination(api_key: str, latitude: float | None, longitude: float | None, address: str) -> tuple[float, float]:
    if latitude is not None and longitude is not None:
        return latitude, longitude
    if not address.strip():
        raise RouteLookupError("This shipment has no delivery coordinates.")
    response = httpx.get(
        "https://maps.googleapis.com/maps/api/geocode/json",
        params={"address": address, "key": api_key},
        timeout=8,
    )
    response.raise_for_status()
    payload = response.json()
    results = payload.get("results") or []
    if payload.get("status") != "OK" or not results:
        raise RouteLookupError("The delivery address could not be located.")
    location = results[0]["geometry"]["location"]
    return float(location["lat"]), float(location["lng"])


def _directions(
    api_key: str,
    origin_latitude: float,
    origin_longitude: float,
    destination_latitude: float,
    destination_longitude: float,
) -> RouteEstimate:
    response = httpx.get(
        "https://maps.googleapis.com/maps/api/directions/json",
        params={
            "origin": f"{origin_latitude},{origin_longitude}",
            "destination": f"{destination_latitude},{destination_longitude}",
            "key": api_key,
        },
        timeout=8,
    )
    response.raise_for_status()
    payload = response.json()
    routes = payload.get("routes") or []
    if payload.get("status") != "OK" or not routes:
        raise RouteLookupError("No driving route is available for this delivery.")
    leg = routes[0]["legs"][0]
    duration = int(leg["duration"]["value"])
    now = datetime.now(UTC)
    return RouteEstimate(
        available=True,
        distance_meters=int(leg["distance"]["value"]),
        duration_seconds=duration,
        eta=now + timedelta(seconds=duration),
        points=_decode_polyline(routes[0].get("overview_polyline", {}).get("points", "")),
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
