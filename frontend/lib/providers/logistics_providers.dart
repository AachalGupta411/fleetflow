import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/driver_profile.dart';
import '../models/shipment.dart';
import '../models/vehicle.dart';
import '../services/logistics_service.dart';
import 'auth_provider.dart';

final shipmentListProvider = FutureProvider<List<Shipment>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.user == null) {
    return const [];
  }
  final service = ref.watch(logisticsServiceProvider);
  if (auth.user!.role == 'DRIVER') {
    return service.driverShipments();
  }
  return service.shipments();
});

final shipmentProvider = FutureProvider.family<Shipment, String>((ref, id) async {
  ref.watch(authProvider);
  return ref.watch(logisticsServiceProvider).shipment(id);
});

final driverListProvider = FutureProvider<List<DriverProfile>>((ref) async {
  if (ref.watch(authProvider).user == null) {
    return const [];
  }
  return ref.watch(logisticsServiceProvider).drivers();
});

final myDriverProvider = FutureProvider<DriverProfile>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null || user.role != 'DRIVER') {
    throw StateError('Driver profile is only available to drivers');
  }
  return ref.watch(logisticsServiceProvider).myDriver();
});

final vehicleListProvider = FutureProvider<List<VehicleRecord>>((ref) async {
  if (ref.watch(authProvider).user == null) {
    return const [];
  }
  return ref.watch(logisticsServiceProvider).vehicles();
});

final userListProvider = FutureProvider<List<AppUserRecord>>((ref) async {
  if (ref.watch(authProvider).user == null) {
    return const [];
  }
  return ref.watch(logisticsServiceProvider).users();
});
