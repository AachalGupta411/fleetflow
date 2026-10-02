import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/operations_math.dart';
import '../../models/operations.dart';
import '../../services/operations_service.dart';
import '../../widgets/fleet_scaffold.dart';

class OpsDriverScreen extends ConsumerWidget {
  const OpsDriverScreen({super.key, required this.driverId});

  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(opsDriverProvider(driverId));
    return FleetScaffold(
      title: 'Driver',
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorPane(
          message: error.toString(),
          onRetry: () => ref.invalidate(opsDriverProvider(driverId)),
        ),
        data: (item) {
          final performance = item.performance;
          final rates = outcomeRates(performance.completedDeliveries, performance.failedDeliveries);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(item.driverName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              Text(item.status),
              Text('Vehicle ${item.vehicleNumber ?? 'none'}'),
              if (item.activeTrackingNumber != null)
                Text('Active shipment ${item.activeTrackingNumber} · ${item.activeShipmentStatus}'),
              const SizedBox(height: 12),
              Text('Assigned ${performance.assignedDeliveries}'),
              Text('Completed ${performance.completedDeliveries}'),
              Text('Failed ${performance.failedDeliveries}'),
              Text('Active now ${performance.activeDeliveryCount}'),
              Text('Completion ${rates.completion == null ? 'unavailable' : '${(rates.completion! * 100).toStringAsFixed(0)}%'}'),
              Text(
                'Average duration ${performance.averageDeliveryDurationMinutes == null ? 'unavailable' : '${performance.averageDeliveryDurationMinutes} min'}',
              ),
              Text(
                'Average distance ${performance.averageDistanceKm == null ? 'unavailable' : '${performance.averageDistanceKm} km'}',
              ),
              const SizedBox(height: 12),
              const Text('Recent activity', style: TextStyle(fontWeight: FontWeight.w700)),
              if (item.recentActivity.isEmpty) const Text('No recorded activity in view.'),
              for (final event in item.recentActivity)
                Text('${event.trackingNumber} · ${event.eventType}'),
            ],
          );
        },
      ),
    );
  }
}

final opsDriverProvider = FutureProvider.family<DriverOperationsView, String>((ref, id) {
  final window = DateWindow.preset(AnalyticsPreset.last30, DateTime.now());
  return ref.watch(operationsServiceProvider).driver(id, window);
});
