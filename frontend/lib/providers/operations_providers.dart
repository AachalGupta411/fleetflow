import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/operations_math.dart';
import '../models/operations.dart';
import '../services/operations_service.dart';
import 'auth_provider.dart';

class AnalyticsRange extends Notifier<AnalyticsPreset> {
  @override
  AnalyticsPreset build() => AnalyticsPreset.last30;

  void select(AnalyticsPreset preset) => state = preset;
}

final analyticsRangeProvider = NotifierProvider<AnalyticsRange, AnalyticsPreset>(AnalyticsRange.new);

final operationsOverviewProvider = FutureProvider<OperationsOverview>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null || !canViewOperations(user.role)) {
    throw StateError('Operations are available to fleet managers and admins');
  }
  return ref.watch(operationsServiceProvider).overview();
});

final deliveryAnalyticsProvider = FutureProvider<DeliveryAnalytics>((ref) async {
  final window = DateWindow.preset(ref.watch(analyticsRangeProvider), DateTime.now());
  return ref.watch(operationsServiceProvider).deliveries(window);
});

final fuelAnalyticsProvider = FutureProvider<FuelAnalytics>((ref) async {
  final window = DateWindow.preset(ref.watch(analyticsRangeProvider), DateTime.now());
  return ref.watch(operationsServiceProvider).fuel(window);
});

final failureReasonsProvider = FutureProvider<List<FailureReasonCount>>((ref) async {
  final window = DateWindow.preset(ref.watch(analyticsRangeProvider), DateTime.now());
  return ref.watch(operationsServiceProvider).failureReasons(window);
});

final driverPerformanceListProvider = FutureProvider<List<DriverPerformance>>((ref) async {
  final window = DateWindow.preset(ref.watch(analyticsRangeProvider), DateTime.now());
  return ref.watch(operationsServiceProvider).drivers(window);
});
