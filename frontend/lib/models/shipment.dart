class Shipment {
  const Shipment({
    required this.id,
    required this.trackingNumber,
    required this.customerId,
    required this.customerName,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.packageDescription,
    required this.priority,
    required this.status,
    this.assignedDriverId,
    this.driverName,
    this.assignedVehicleId,
    this.vehicleNumber,
    this.failureReason,
    this.deliveryId,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.failureCode,
    this.failureNotes,
    this.recipientName,
    this.geofenceEnteredAt,
    this.deliveredAt,
    this.failedAt,
    this.podAvailable = false,
    this.createdAt,
  });

  final String id;
  final String trackingNumber;
  final String customerId;
  final String customerName;
  final String pickupAddress;
  final String deliveryAddress;
  final String packageDescription;
  final String priority;
  final String status;
  final String? assignedDriverId;
  final String? driverName;
  final String? assignedVehicleId;
  final String? vehicleNumber;
  final String? failureReason;
  final String? deliveryId;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? failureCode;
  final String? failureNotes;
  final String? recipientName;
  final DateTime? geofenceEnteredAt;
  final DateTime? deliveredAt;
  final DateTime? failedAt;
  final bool podAvailable;
  final DateTime? createdAt;

  bool get isActive =>
      status != 'DELIVERED' && status != 'FAILED' && status != 'CANCELLED';

  factory Shipment.fromJson(Map<String, dynamic> json) {
    return Shipment(
      id: json['id'] as String,
      trackingNumber: json['tracking_number'] as String,
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String,
      pickupAddress: json['pickup_address'] as String,
      deliveryAddress: json['delivery_address'] as String,
      packageDescription: json['package_description'] as String,
      priority: json['priority'] as String,
      status: json['status'] as String,
      assignedDriverId: json['assigned_driver_id'] as String?,
      driverName: json['driver_name'] as String?,
      assignedVehicleId: json['assigned_vehicle_id'] as String?,
      vehicleNumber: json['vehicle_number'] as String?,
      failureReason: json['failure_reason'] as String?,
      deliveryId: json['delivery_id'] as String?,
      deliveryLatitude: _coord(json['delivery_latitude']),
      deliveryLongitude: _coord(json['delivery_longitude']),
      failureCode: json['failure_code'] as String?,
      failureNotes: json['failure_notes'] as String?,
      recipientName: json['recipient_name'] as String?,
      geofenceEnteredAt: _time(json['geofence_entered_at']),
      deliveredAt: _time(json['delivered_at']),
      failedAt: _time(json['failed_at']),
      podAvailable: json['pod_available'] as bool? ?? false,
      createdAt: _time(json['created_at']),
    );
  }
}

double? _coord(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

DateTime? _time(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
