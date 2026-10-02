import '../core/operations_math.dart';

class FleetUtilization {
  const FleetUtilization({
    required this.totalVehicles,
    required this.activeVehicles,
    required this.availableVehicles,
    required this.assignedVehicles,
    required this.vehiclesOnDelivery,
    required this.totalDrivers,
    required this.availableDrivers,
    required this.driversOnDelivery,
    required this.activeDeliveries,
    required this.completedDeliveries,
    required this.failedDeliveries,
    required this.completionRate,
  });

  final int totalVehicles;
  final int activeVehicles;
  final int availableVehicles;
  final int assignedVehicles;
  final int vehiclesOnDelivery;
  final int totalDrivers;
  final int availableDrivers;
  final int driversOnDelivery;
  final int activeDeliveries;
  final int completedDeliveries;
  final int failedDeliveries;
  final double? completionRate;

  factory FleetUtilization.fromJson(Map<String, dynamic> json) {
    return FleetUtilization(
      totalVehicles: json['total_vehicles'] as int,
      activeVehicles: json['active_vehicles'] as int,
      availableVehicles: json['available_vehicles'] as int,
      assignedVehicles: json['assigned_vehicles'] as int,
      vehiclesOnDelivery: json['vehicles_on_delivery'] as int,
      totalDrivers: json['total_drivers'] as int,
      availableDrivers: json['available_drivers'] as int,
      driversOnDelivery: json['drivers_on_delivery'] as int,
      activeDeliveries: json['active_deliveries'] as int,
      completedDeliveries: json['completed_deliveries'] as int,
      failedDeliveries: json['failed_deliveries'] as int,
      completionRate: (json['completion_rate'] as num?)?.toDouble(),
    );
  }
}

class OperationsOverview {
  const OperationsOverview({
    required this.fleet,
    required this.fuelLiters,
    required this.fuelCost,
    required this.averagePricePerLiter,
    required this.averageDeliveryDurationMinutes,
  });

  final FleetUtilization fleet;
  final String fuelLiters;
  final String fuelCost;
  final String? averagePricePerLiter;
  final double? averageDeliveryDurationMinutes;

  factory OperationsOverview.fromJson(Map<String, dynamic> json) {
    return OperationsOverview(
      fleet: FleetUtilization.fromJson(json['fleet'] as Map<String, dynamic>),
      fuelLiters: json['fuel_liters'].toString(),
      fuelCost: json['fuel_cost'].toString(),
      averagePricePerLiter: json['average_price_per_liter']?.toString(),
      averageDeliveryDurationMinutes: (json['average_delivery_duration_minutes'] as num?)?.toDouble(),
    );
  }
}

class BucketCount {
  const BucketCount({required this.period, required this.count});

  final String period;
  final int count;

  factory BucketCount.fromJson(Map<String, dynamic> json) {
    return BucketCount(period: json['period'] as String, count: json['count'] as int);
  }
}

class DeliveryAnalytics {
  const DeliveryAnalytics({
    required this.volume,
    required this.completed,
    required this.failed,
    required this.active,
    required this.completionRate,
    required this.averageDeliveryDurationMinutes,
  });

  final List<BucketCount> volume;
  final int completed;
  final int failed;
  final int active;
  final double? completionRate;
  final double? averageDeliveryDurationMinutes;

  bool get isEmpty => volume.isEmpty && completed == 0 && failed == 0;

  factory DeliveryAnalytics.fromJson(Map<String, dynamic> json) {
    final volume = json['volume'] as List<dynamic>? ?? const [];
    return DeliveryAnalytics(
      volume: volume.map((item) => BucketCount.fromJson(item as Map<String, dynamic>)).toList(),
      completed: json['completed'] as int,
      failed: json['failed'] as int,
      active: json['active'] as int,
      completionRate: (json['completion_rate'] as num?)?.toDouble(),
      averageDeliveryDurationMinutes: (json['average_delivery_duration_minutes'] as num?)?.toDouble(),
    );
  }
}

class FailureReasonCount {
  const FailureReasonCount({required this.reason, required this.count});

  final String reason;
  final int count;

  factory FailureReasonCount.fromJson(Map<String, dynamic> json) {
    return FailureReasonCount(reason: json['reason'] as String, count: json['count'] as int);
  }
}

class FuelVehicleTotal {
  const FuelVehicleTotal({
    required this.vehicleId,
    required this.vehicleNumber,
    required this.liters,
    required this.totalCost,
  });

  final String vehicleId;
  final String vehicleNumber;
  final String liters;
  final String totalCost;

  factory FuelVehicleTotal.fromJson(Map<String, dynamic> json) {
    return FuelVehicleTotal(
      vehicleId: json['vehicle_id'] as String,
      vehicleNumber: json['vehicle_number'] as String,
      liters: json['liters'].toString(),
      totalCost: json['total_cost'].toString(),
    );
  }
}

class CostPoint {
  const CostPoint({required this.period, required this.totalCost});

  final String period;
  final String totalCost;

  factory CostPoint.fromJson(Map<String, dynamic> json) {
    return CostPoint(period: json['period'] as String, totalCost: json['total_cost'].toString());
  }
}

class FuelAnalytics {
  const FuelAnalytics({
    required this.totalLiters,
    required this.totalCost,
    required this.averagePricePerLiter,
    required this.byVehicle,
    required this.costTrend,
  });

  final String totalLiters;
  final String totalCost;
  final String? averagePricePerLiter;
  final List<FuelVehicleTotal> byVehicle;
  final List<CostPoint> costTrend;

  bool get isEmpty => parseAmount(totalLiters) == 0 && byVehicle.isEmpty;

  factory FuelAnalytics.fromJson(Map<String, dynamic> json) {
    final vehicles = json['by_vehicle'] as List<dynamic>? ?? const [];
    final trend = json['cost_trend'] as List<dynamic>? ?? const [];
    return FuelAnalytics(
      totalLiters: json['total_liters'].toString(),
      totalCost: json['total_cost'].toString(),
      averagePricePerLiter: json['average_price_per_liter']?.toString(),
      byVehicle: vehicles.map((item) => FuelVehicleTotal.fromJson(item as Map<String, dynamic>)).toList(),
      costTrend: trend.map((item) => CostPoint.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }
}

class DriverPerformance {
  const DriverPerformance({
    required this.driverId,
    required this.driverName,
    required this.currentStatus,
    required this.assignedDeliveries,
    required this.completedDeliveries,
    required this.failedDeliveries,
    required this.activeDeliveryCount,
    required this.completionRate,
    required this.failureRate,
    required this.averageDeliveryDurationMinutes,
    required this.averageDistanceKm,
  });

  final String driverId;
  final String driverName;
  final String currentStatus;
  final int assignedDeliveries;
  final int completedDeliveries;
  final int failedDeliveries;
  final int activeDeliveryCount;
  final double? completionRate;
  final double? failureRate;
  final double? averageDeliveryDurationMinutes;
  final double? averageDistanceKm;

  factory DriverPerformance.fromJson(Map<String, dynamic> json) {
    return DriverPerformance(
      driverId: json['driver_id'] as String,
      driverName: json['driver_name'] as String,
      currentStatus: json['current_status'] as String,
      assignedDeliveries: json['assigned_deliveries'] as int,
      completedDeliveries: json['completed_deliveries'] as int,
      failedDeliveries: json['failed_deliveries'] as int,
      activeDeliveryCount: json['active_delivery_count'] as int,
      completionRate: (json['completion_rate'] as num?)?.toDouble(),
      failureRate: (json['failure_rate'] as num?)?.toDouble(),
      averageDeliveryDurationMinutes: (json['average_delivery_duration_minutes'] as num?)?.toDouble(),
      averageDistanceKm: (json['average_distance_km'] as num?)?.toDouble(),
    );
  }
}

class FleetVehicleRow {
  const FleetVehicleRow({
    required this.vehicleId,
    required this.vehicleNumber,
    required this.status,
    required this.serviceStatus,
    required this.fuelLiters,
    required this.fuelCost,
    this.driverName,
    this.trackingNumber,
    this.shipmentStatus,
    this.currentOdometerKm,
  });

  final String vehicleId;
  final String vehicleNumber;
  final String status;
  final String? driverName;
  final String? trackingNumber;
  final String? shipmentStatus;
  final String serviceStatus;
  final String? currentOdometerKm;
  final String fuelLiters;
  final String fuelCost;

  factory FleetVehicleRow.fromJson(Map<String, dynamic> json) {
    return FleetVehicleRow(
      vehicleId: json['vehicle_id'] as String,
      vehicleNumber: json['vehicle_number'] as String,
      status: json['status'] as String,
      driverName: json['driver_name'] as String?,
      trackingNumber: json['tracking_number'] as String?,
      shipmentStatus: json['shipment_status'] as String?,
      serviceStatus: json['service_status'] as String? ?? 'OK',
      currentOdometerKm: json['current_odometer_km']?.toString(),
      fuelLiters: json['fuel_liters'].toString(),
      fuelCost: json['fuel_cost'].toString(),
    );
  }
}

class DriverActivityItem {
  const DriverActivityItem({
    required this.trackingNumber,
    required this.eventType,
    required this.createdAt,
  });

  final String trackingNumber;
  final String eventType;
  final String createdAt;

  factory DriverActivityItem.fromJson(Map<String, dynamic> json) {
    return DriverActivityItem(
      trackingNumber: json['tracking_number'] as String,
      eventType: json['event_type'] as String,
      createdAt: json['created_at'] as String,
    );
  }
}

class DriverOperationsView {
  const DriverOperationsView({
    required this.driverName,
    required this.status,
    required this.performance,
    required this.recentActivity,
    this.vehicleNumber,
    this.activeTrackingNumber,
    this.activeShipmentStatus,
  });

  final String driverName;
  final String status;
  final String? vehicleNumber;
  final String? activeTrackingNumber;
  final String? activeShipmentStatus;
  final DriverPerformance performance;
  final List<DriverActivityItem> recentActivity;

  factory DriverOperationsView.fromJson(Map<String, dynamic> json) {
    final activity = json['recent_activity'] as List<dynamic>? ?? const [];
    return DriverOperationsView(
      driverName: json['driver_name'] as String,
      status: json['status'] as String,
      vehicleNumber: json['vehicle_number'] as String?,
      activeTrackingNumber: json['active_tracking_number'] as String?,
      activeShipmentStatus: json['active_shipment_status'] as String?,
      performance: DriverPerformance.fromJson(json['performance'] as Map<String, dynamic>),
      recentActivity: activity.map((item) => DriverActivityItem.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }
}

class FuelBrief {
  const FuelBrief({
    required this.fuelDate,
    required this.liters,
    required this.totalCost,
    this.fuelStation,
  });

  final String fuelDate;
  final String liters;
  final String totalCost;
  final String? fuelStation;

  factory FuelBrief.fromJson(Map<String, dynamic> json) {
    return FuelBrief(
      fuelDate: json['fuel_date'] as String,
      liters: json['liters'].toString(),
      totalCost: json['total_cost'].toString(),
      fuelStation: json['fuel_station'] as String?,
    );
  }
}

class VehicleOperationsView {
  const VehicleOperationsView({
    required this.row,
    required this.model,
    required this.deliveryCount,
    required this.recentFuel,
    this.fuelType,
    this.lastServiceDate,
    this.nextServiceDueKm,
  });

  final FleetVehicleRow row;
  final String model;
  final String? fuelType;
  final String? lastServiceDate;
  final String? nextServiceDueKm;
  final int deliveryCount;
  final List<FuelBrief> recentFuel;

  factory VehicleOperationsView.fromJson(Map<String, dynamic> json) {
    final fuel = json['recent_fuel'] as List<dynamic>? ?? const [];
    return VehicleOperationsView(
      row: FleetVehicleRow.fromJson(json),
      model: json['model'] as String? ?? '',
      fuelType: json['fuel_type'] as String?,
      lastServiceDate: json['last_service_date'] as String?,
      nextServiceDueKm: json['next_service_due_km']?.toString(),
      deliveryCount: json['delivery_count'] as int? ?? 0,
      recentFuel: fuel.map((item) => FuelBrief.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }
}
