class VehicleRecord {
  const VehicleRecord({
    required this.id,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.model,
    required this.capacity,
    required this.status,
    this.driverId,
    this.driverName,
  });

  final String id;
  final String vehicleNumber;
  final String vehicleType;
  final String model;
  final int capacity;
  final String status;
  final String? driverId;
  final String? driverName;

  factory VehicleRecord.fromJson(Map<String, dynamic> json) {
    return VehicleRecord(
      id: json['id'] as String,
      vehicleNumber: json['vehicle_number'] as String,
      vehicleType: json['vehicle_type'] as String,
      model: json['model'] as String,
      capacity: (json['capacity'] as num).toInt(),
      status: json['status'] as String,
      driverId: json['driver_id'] as String?,
      driverName: json['driver_name'] as String?,
    );
  }
}
