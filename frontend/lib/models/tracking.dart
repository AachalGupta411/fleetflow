class FleetDriver {
  const FleetDriver({
    required this.driverId,
    required this.driverName,
    required this.freshness,
    required this.shipmentId,
    required this.trackingNumber,
    required this.status,
    this.vehicleId,
    this.vehicleNumber,
    this.latitude,
    this.longitude,
    this.lastUpdated,
  });

  final String driverId;
  final String driverName;
  final String? vehicleId;
  final String? vehicleNumber;
  final double? latitude;
  final double? longitude;
  final DateTime? lastUpdated;
  final String freshness;
  final String shipmentId;
  final String trackingNumber;
  final String status;

  bool get hasFix => latitude != null && longitude != null;

  factory FleetDriver.fromJson(Map<String, dynamic> json) {
    return FleetDriver(
      driverId: json['driver_id'] as String,
      driverName: json['driver_name'] as String,
      vehicleId: json['vehicle_id'] as String?,
      vehicleNumber: json['vehicle_number'] as String?,
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      lastUpdated: _asTime(json['last_updated']),
      freshness: json['freshness'] as String? ?? 'OFFLINE',
      shipmentId: json['shipment_id'] as String,
      trackingNumber: json['tracking_number'] as String,
      status: json['status'] as String,
    );
  }
}

class RoutePoint {
  const RoutePoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      latitude: _asDouble(json['latitude']) ?? 0,
      longitude: _asDouble(json['longitude']) ?? 0,
    );
  }
}

class ShipmentTracking {
  const ShipmentTracking({
    required this.shipmentId,
    required this.trackingNumber,
    required this.status,
    required this.freshness,
    required this.deliveryAddress,
    required this.routeAvailable,
    required this.routePoints,
    required this.routesConfigured,
    this.driverId,
    this.driverName,
    this.vehicleId,
    this.vehicleNumber,
    this.latitude,
    this.longitude,
    this.lastUpdated,
    this.destinationLatitude,
    this.destinationLongitude,
    this.distanceMeters,
    this.durationSeconds,
    this.eta,
    this.message,
  });

  final String shipmentId;
  final String trackingNumber;
  final String status;
  final String? driverId;
  final String? driverName;
  final String? vehicleId;
  final String? vehicleNumber;
  final double? latitude;
  final double? longitude;
  final DateTime? lastUpdated;
  final String freshness;
  final String deliveryAddress;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final bool routeAvailable;
  final int? distanceMeters;
  final int? durationSeconds;
  final DateTime? eta;
  final List<RoutePoint> routePoints;
  final String? message;
  final bool routesConfigured;

  bool get hasFix => latitude != null && longitude != null;

  factory ShipmentTracking.fromJson(Map<String, dynamic> json) {
    final points = json['route_points'];
    return ShipmentTracking(
      shipmentId: json['shipment_id'] as String,
      trackingNumber: json['tracking_number'] as String,
      status: json['status'] as String,
      driverId: json['driver_id'] as String?,
      driverName: json['driver_name'] as String?,
      vehicleId: json['vehicle_id'] as String?,
      vehicleNumber: json['vehicle_number'] as String?,
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      lastUpdated: _asTime(json['last_updated']),
      freshness: json['freshness'] as String? ?? 'OFFLINE',
      deliveryAddress: json['delivery_address'] as String? ?? '',
      destinationLatitude: _asDouble(json['destination_latitude']),
      destinationLongitude: _asDouble(json['destination_longitude']),
      routeAvailable: json['route_available'] as bool? ?? false,
      distanceMeters: (json['distance_meters'] as num?)?.toInt(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      eta: _asTime(json['eta']),
      routePoints: points is List
          ? points.map((item) => RoutePoint.fromJson(item as Map<String, dynamic>)).toList()
          : const [],
      message: json['message'] as String?,
      routesConfigured: json['routes_configured'] as bool? ?? false,
    );
  }
}

double? _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

DateTime? _asTime(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
