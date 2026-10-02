import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/operations_math.dart';
import '../models/operations.dart';
import '../providers/api_providers.dart';

class OperationsService {
  OperationsService(this._client);

  final ApiClient _client;

  Future<OperationsOverview> overview() => _guard(() async {
    final data = await _client.send('GET', '/api/v1/operations/overview');
    return OperationsOverview.fromJson(data as Map<String, dynamic>);
  });

  Future<List<FleetVehicleRow>> fleet({String? status}) => _guard(() async {
    final query = status == null ? '' : '?status=$status';
    final data = await _client.send('GET', '/api/v1/operations/fleet$query');
    return (data as List<dynamic>)
        .map((item) => FleetVehicleRow.fromJson(item as Map<String, dynamic>))
        .toList();
  });

  Future<VehicleOperationsView> vehicle(String id) => _guard(() async {
    final data = await _client.send('GET', '/api/v1/operations/vehicles/$id');
    return VehicleOperationsView.fromJson(data as Map<String, dynamic>);
  });

  Future<DriverOperationsView> driver(String id, DateWindow window) => _guard(() async {
    final data = await _client.send('GET', '/api/v1/operations/drivers/$id?${window.query}');
    return DriverOperationsView.fromJson(data as Map<String, dynamic>);
  });

  Future<List<DriverPerformance>> drivers(DateWindow window) => _guard(() async {
    final data = await _client.send('GET', '/api/v1/analytics/drivers?${window.query}');
    return (data as List<dynamic>)
        .map((item) => DriverPerformance.fromJson(item as Map<String, dynamic>))
        .toList();
  });

  Future<DeliveryAnalytics> deliveries(DateWindow window) => _guard(() async {
    final data = await _client.send('GET', '/api/v1/analytics/deliveries?${window.query}&bucket=day');
    return DeliveryAnalytics.fromJson(data as Map<String, dynamic>);
  });

  Future<FuelAnalytics> fuel(DateWindow window) => _guard(() async {
    final data = await _client.send('GET', '/api/v1/analytics/fuel?${window.query}');
    return FuelAnalytics.fromJson(data as Map<String, dynamic>);
  });

  Future<List<FailureReasonCount>> failureReasons(DateWindow window) => _guard(() async {
    final data = await _client.send('GET', '/api/v1/analytics/failure-reasons?${window.query}');
    return (data as List<dynamic>)
        .map((item) => FailureReasonCount.fromJson(item as Map<String, dynamic>))
        .toList();
  });

  Future<void> recordFuel({
    required String vehicleId,
    required String liters,
    required String pricePerLiter,
    required String fuelDate,
    String? odometerKm,
    String? fuelStation,
    String? notes,
  }) => _guard(() async {
    await _client.send(
      'POST',
      '/api/v1/fuel',
      body: {
        'vehicle_id': vehicleId,
        'liters': liters,
        'price_per_liter': pricePerLiter,
        'fuel_date': fuelDate,
        if (odometerKm != null && odometerKm.isNotEmpty) 'odometer_km': odometerKm,
        if (fuelStation != null && fuelStation.isNotEmpty) 'fuel_station': fuelStation,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(error.toString());
    }
  }
}

final operationsServiceProvider = Provider<OperationsService>((ref) {
  return OperationsService(ref.watch(apiClientProvider));
});
