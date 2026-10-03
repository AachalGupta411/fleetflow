import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/operations_math.dart';
import '../../core/router/app_routes.dart';
import '../../models/operations.dart';
import '../../providers/operations_providers.dart';
import '../../widgets/dark_page.dart';
import '../../widgets/operations_charts.dart';

class OperationsDashboardScreen extends ConsumerWidget {
  const OperationsDashboardScreen({super.key, required this.admin});

  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(operationsOverviewProvider);
    return DarkPage(
      title: 'Operations',
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => DarkMessage(
          message: error.toString(),
          onRetry: () => ref.invalidate(operationsOverviewProvider),
        ),
        data: (data) {
          final fleet = data.fleet;
          final fuelRecorded = (parseAmount(data.fuelLiters) ?? 0) > 0;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(operationsOverviewProvider),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                DarkSection(
                  title: 'Fleet',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MetricRow(
                        items: [
                          MetricTile('Vehicles', '${fleet.totalVehicles}'),
                          MetricTile('Available', '${fleet.availableVehicles}'),
                          MetricTile('On delivery', '${fleet.vehiclesOnDelivery}'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(_fleetNote(fleet), style: const TextStyle(color: DarkColors.muted, height: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DarkSection(
                  title: 'Drivers',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MetricRow(
                        items: [
                          MetricTile('Drivers', '${fleet.totalDrivers}'),
                          MetricTile('Available', '${fleet.availableDrivers}'),
                          MetricTile('On delivery', '${fleet.driversOnDelivery}'),
                        ],
                      ),
                      if (fleet.availableDrivers == 0 && fleet.totalDrivers > 0) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Every driver is on an active delivery. New shipments cannot be assigned until one finishes.',
                          style: TextStyle(color: DarkColors.muted, height: 1.35),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DarkSection(
                  title: 'Deliveries',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MetricRow(
                        items: [
                          MetricTile('Active', '${fleet.activeDeliveries}'),
                          MetricTile('Completed', '${fleet.completedDeliveries}'),
                          MetricTile('Failed', '${fleet.failedDeliveries}'),
                          MetricTile('Completion', _rate(fleet.completionRate)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        fleet.completionRate == null
                            ? 'No finished deliveries yet.'
                            : 'Completion counts finished deliveries only. Active shipments are still open.',
                        style: const TextStyle(color: DarkColors.muted, height: 1.35),
                      ),
                      if (data.averageDeliveryDurationMinutes != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Average delivery time ${data.averageDeliveryDurationMinutes!.toStringAsFixed(0)} min',
                          style: const TextStyle(color: DarkColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DarkSection(
                  title: 'Fuel',
                  child: fuelRecorded
                      ? MetricRow(
                          items: [
                            MetricTile('Liters', '${data.fuelLiters} L'),
                            MetricTile('Cost', formatInr(data.fuelCost)),
                            MetricTile('Avg / L', data.averagePricePerLiter == null ? '—' : formatInr(data.averagePricePerLiter!)),
                          ],
                        )
                      : const Text('No fuel recorded yet.', style: TextStyle(color: DarkColors.muted)),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _LinkButton(
                      icon: Icons.insights_outlined,
                      label: 'Analytics',
                      onPressed: () => context.go(admin ? AppRoutes.adminAnalytics : AppRoutes.managerAnalytics),
                    ),
                    _LinkButton(
                      icon: Icons.grid_view_outlined,
                      label: 'Fleet board',
                      onPressed: () => context.go(admin ? AppRoutes.adminBoard : AppRoutes.managerBoard),
                    ),
                    _LinkButton(
                      icon: Icons.currency_rupee,
                      label: 'Pricing',
                      onPressed: () => context.go(admin ? AppRoutes.adminPricing : AppRoutes.managerPricing),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: DarkColors.text,
        side: const BorderSide(color: DarkColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

String _rate(double? value) {
  if (value == null) {
    return '—';
  }
  return '${(value * 100).toStringAsFixed(0)}%';
}

String _fleetNote(FleetUtilization fleet) {
  if (fleet.totalVehicles == 0) {
    return 'No vehicles added yet.';
  }
  final idle = fleet.totalVehicles - fleet.vehiclesOnDelivery - fleet.availableVehicles;
  if (idle > 0) {
    return '$idle assigned but not yet on the road.';
  }
  if (fleet.availableVehicles == 0) {
    return 'Every vehicle is committed to a delivery.';
  }
  return '${fleet.availableVehicles} free to assign right now.';
}
