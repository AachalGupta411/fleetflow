import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/driver_profile.dart';
import '../models/shipment.dart';
import '../models/vehicle.dart';
import '../providers/api_providers.dart';
import '../providers/auth_provider.dart';

class LogisticsService {
  LogisticsService(this._ref, this._client);

  final Ref _ref;
  final ApiClient _client;

  Future<List<Shipment>> shipments() => _guard(() async {
    final data = await _client.send('GET', '/api/v1/shipments');
    return _shipments(data);
  });

  Future<List<Shipment>> driverShipments() => _guard(() async {
    final data = await _client.send('GET', '/api/v1/driver/shipments');
    return _shipments(data);
  });

  Future<Shipment> shipment(String id) => _guard(() async {
    final data = await _client.send('GET', '/api/v1/shipments/$id');
    return Shipment.fromJson(data as Map<String, dynamic>);
  });

  Future<Shipment> createShipment({
    required String pickupAddress,
    required String deliveryAddress,
    required String packageDescription,
    required String priority,
  }) => _guard(() async {
    final data = await _client.send(
      'POST',
      '/api/v1/shipments',
      body: {
        'pickup_address': pickupAddress.trim(),
        'delivery_address': deliveryAddress.trim(),
        'package_description': packageDescription.trim(),
        'priority': priority,
      },
    );
    return Shipment.fromJson(data as Map<String, dynamic>);
  });

  Future<Shipment> assignShipment({
    required String shipmentId,
    required String driverId,
    required String vehicleId,
  }) => _guard(() async {
    final data = await _client.send(
      'POST',
      '/api/v1/shipments/$shipmentId/assign',
      body: {'driver_id': driverId, 'vehicle_id': vehicleId},
    );
    return Shipment.fromJson(data as Map<String, dynamic>);
  });

  Future<Shipment> updateStatus({
    required String shipmentId,
    required String status,
    String? failureReason,
  }) => _guard(() async {
    final data = await _client.send(
      'POST',
      '/api/v1/shipments/$shipmentId/status',
      body: {
        'status': status,
        'failure_reason': ?failureReason,
      },
    );
    return Shipment.fromJson(data as Map<String, dynamic>);
  });

  Future<List<DriverProfile>> drivers() => _guard(() async {
    final data = await _client.send('GET', '/api/v1/drivers');
    return (data as List<dynamic>)
        .map((item) => DriverProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  });

  Future<DriverProfile> myDriver() => _guard(() async {
    final data = await _client.send('GET', '/api/v1/drivers/me');
    return DriverProfile.fromJson(data as Map<String, dynamic>);
  });

  Future<DriverProfile> createDriver({
    required String name,
    required String email,
    required String password,
    required String licenseNumber,
    required String licenseExpiry,
    String? phone,
  }) => _guard(() async {
    final data = await _client.send(
      'POST',
      '/api/v1/drivers',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'license_number': licenseNumber.trim(),
        'license_expiry': licenseExpiry,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    );
    return DriverProfile.fromJson(data as Map<String, dynamic>);
  });

  Future<List<VehicleRecord>> vehicles() => _guard(() async {
    final data = await _client.send('GET', '/api/v1/vehicles');
    return (data as List<dynamic>)
        .map((item) => VehicleRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  });

  Future<VehicleRecord> createVehicle({
    required String vehicleNumber,
    required String vehicleType,
    required String model,
    required int capacity,
  }) => _guard(() async {
    final data = await _client.send(
      'POST',
      '/api/v1/vehicles',
      body: {
        'vehicle_number': vehicleNumber.trim(),
        'vehicle_type': vehicleType.trim(),
        'model': model.trim(),
        'capacity': capacity,
      },
    );
    return VehicleRecord.fromJson(data as Map<String, dynamic>);
  });

  Future<List<AppUserRecord>> users() => _guard(() async {
    final data = await _client.send('GET', '/api/v1/users');
    return (data as List<dynamic>)
        .map((item) => AppUserRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  });

  Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) => _guard(() async {
    await _client.send(
      'POST',
      '/api/v1/users',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': role,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    );
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _ref.read(authProvider.notifier).logout();
      }
      rethrow;
    }
  }

  List<Shipment> _shipments(dynamic data) {
    return (data as List<dynamic>)
        .map((item) => Shipment.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class AppUserRecord {
  const AppUserRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.phone,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final bool isActive;

  factory AppUserRecord.fromJson(Map<String, dynamic> json) {
    return AppUserRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

final logisticsServiceProvider = Provider<LogisticsService>((ref) {
  return LogisticsService(ref, ref.watch(apiClientProvider));
});
