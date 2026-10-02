import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../providers/operations_providers.dart';
import '../../widgets/dark_page.dart';
import '../../widgets/date_range_bar.dart';
import '../../widgets/operations_charts.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key, required this.admin});

  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveries = ref.watch(deliveryAnalyticsProvider);
    final fuel = ref.watch(fuelAnalyticsProvider);
    final reasons = ref.watch(failureReasonsProvider);
    final drivers = ref.watch(driverPerformanceListProvider);
    return DarkPage(
      title: 'Analytics',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const DateRangeBar(),
          const SizedBox(height: 16),
          deliveries.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => DarkMessage(message: error.toString(), onRetry: () => ref.invalidate(deliveryAnalyticsProvider)),
            data: (data) {
              if (data.isEmpty && data.active == 0) {
                return const DarkMessage(message: 'No operational data available for this period.');
              }
              return _Section(
                title: 'Deliveries',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Completion ${_percent(data.completionRate)} · Active now ${data.active}',
                      style: const TextStyle(color: DarkColors.text, fontWeight: FontWeight.w600),
                    ),
                    if (data.averageDeliveryDurationMinutes != null)
                      Text('Average duration ${data.averageDeliveryDurationMinutes} min', style: const TextStyle(color: DarkColors.muted)),
                    const SizedBox(height: 16),
                    const Text('Pickup volume', style: TextStyle(color: DarkColors.muted)),
                    VolumeChart(volume: data.volume),
                    const SizedBox(height: 8),
                    const Text('Outcomes', style: TextStyle(color: DarkColors.muted)),
                    OutcomeChart(completed: data.completed, failed: data.failed, active: data.active),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          reasons.when(
            loading: () => const SizedBox.shrink(),
            error: (error, _) => DarkMessage(message: error.toString(), onRetry: () => ref.invalidate(failureReasonsProvider)),
            data: (items) {
              if (items.isEmpty) {
                return const _Section(title: 'Failure reasons', child: Text('No failed deliveries in this period.', style: TextStyle(color: DarkColors.muted)));
              }
              return _Section(
                title: 'Failure reasons',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('${item.reason}: ${item.count}', style: const TextStyle(color: DarkColors.text)),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          fuel.when(
            loading: () => const SizedBox.shrink(),
            error: (error, _) => DarkMessage(message: error.toString(), onRetry: () => ref.invalidate(fuelAnalyticsProvider)),
            data: (data) {
              if (data.isEmpty) {
                return const _Section(title: 'Fuel', child: Text('No fuel recorded in this period.', style: TextStyle(color: DarkColors.muted)));
              }
              return _Section(
                title: 'Fuel',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${data.totalLiters} L · ${data.totalCost}', style: const TextStyle(color: DarkColors.text, fontWeight: FontWeight.w600)),
                    FuelCostChart(points: data.costTrend),
                    for (final vehicle in data.byVehicle)
                      Text('${vehicle.vehicleNumber}: ${vehicle.totalCost}', style: const TextStyle(color: DarkColors.muted)),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          drivers.when(
            loading: () => const SizedBox.shrink(),
            error: (error, _) => DarkMessage(message: error.toString(), onRetry: () => ref.invalidate(driverPerformanceListProvider)),
            data: (items) {
              if (items.isEmpty) {
                return const _Section(title: 'Drivers', child: Text('No drivers to show.', style: TextStyle(color: DarkColors.muted)));
              }
              return _Section(
                title: 'Drivers',
                child: Column(
                  children: [
                    for (final driver in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: DarkColors.panel,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            title: Text(driver.driverName, style: const TextStyle(color: DarkColors.text, fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              '${driver.completedDeliveries} completed · ${driver.failedDeliveries} failed · ${_percent(driver.completionRate)}',
                              style: const TextStyle(color: DarkColors.muted),
                            ),
                            onTap: () => context.push(
                              admin ? AppRoutes.adminDriverOps(driver.driverId) : AppRoutes.managerDriverOps(driver.driverId),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DarkColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DarkColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: DarkColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

String _percent(double? value) {
  if (value == null) {
    return 'no finished deliveries';
  }
  return '${(value * 100).toStringAsFixed(0)}% completion';
}
