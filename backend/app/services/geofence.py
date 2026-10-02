from math import asin, cos, radians, sin, sqrt

from app.core.config import get_settings


def distance_meters(latitude_a: float, longitude_a: float, latitude_b: float, longitude_b: float) -> float:
    """Great-circle distance in meters."""
    earth_radius = 6_371_000
    lat1 = radians(latitude_a)
    lat2 = radians(latitude_b)
    d_lat = radians(latitude_b - latitude_a)
    d_lon = radians(longitude_b - longitude_a)
    haversine = sin(d_lat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(d_lon / 2) ** 2
    return 2 * earth_radius * asin(sqrt(haversine))


def within_geofence(latitude_a: float, longitude_a: float, latitude_b: float, longitude_b: float) -> bool:
    return distance_meters(latitude_a, longitude_a, latitude_b, longitude_b) <= geofence_radius_meters()


def geofence_radius_meters() -> int:
    return get_settings().geofence_radius_meters
