import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../models/operations.dart';
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
              final pickups = data.volume.fold<int>(0, (sum, item) => sum + item.count);
              return DarkSection(
                title: 'Deliveries',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MetricRow(
                      items: [
                        MetricTile('Active', '${data.active}'),
                        MetricTile('Completed', '${data.completed}'),
                        MetricTile('Failed', '${data.failed}'),
                        MetricTile('Completion', _rate(data.completionRate)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data.completionRate == null ? 'No finished deliveries in this period.' : 'Finished deliveries only. Active shipments are still open.',
                      style: const TextStyle(color: DarkColors.muted, height: 1.35),
                    ),
                    if (data.averageDeliveryDurationMinutes != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Average delivery time ${data.averageDeliveryDurationMinutes!.toStringAsFixed(0)} min',
                        style: const TextStyle(color: DarkColors.muted),
                      ),
                    ],
                    const SizedBox(height: 18),
                    BlockLabel('Pickup volume', trailing: pickups == 1 ? '1 pickup' : '$pickups pickups'),
                    const SizedBox(height: 10),
                    VolumeChart(volume: data.volume),
                    const SizedBox(height: 18),
                    const BlockLabel('Outcomes'),
                    const SizedBox(height: 10),
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
                return const DarkSection(title: 'Failure reasons', child: Text('No failed deliveries in this period.', style: TextStyle(color: DarkColors.muted)));
              }
              return DarkSection(
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
                return const DarkSection(title: 'Fuel', child: Text('No fuel recorded in this period.', style: TextStyle(color: DarkColors.muted)));
              }
              return DarkSection(
                title: 'Fuel',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MetricRow(
                      items: [
                        MetricTile('Liters', '${data.totalLiters} L'),
                        MetricTile('Cost', formatInr(data.totalCost)),
                        if (data.averagePricePerLiter != null) MetricTile('Avg / L', formatInr(data.averagePricePerLiter!)),
                      ],
                    ),
                    if (data.costTrend.length >= 2) ...[
                      const SizedBox(height: 16),
                      const BlockLabel('Cost over time'),
                      const SizedBox(height: 8),
                      FuelCostChart(points: data.costTrend),
                    ],
                    if (data.byVehicle.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const BlockLabel('By vehicle'),
                      const SizedBox(height: 8),
                      for (final vehicle in data.byVehicle)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _VehicleFuelRow(vehicle: vehicle),
                        ),
                    ],
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
                return const DarkSection(title: 'Drivers', child: Text('No drivers to show.', style: TextStyle(color: DarkColors.muted)));
              }
              return DarkSection(
                title: 'Drivers',
                child: Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      if (index > 0) const Divider(height: 1, color: DarkColors.line),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(items[index].driverName, style: const TextStyle(color: DarkColors.text, fontWeight: FontWeight.w700)),
                            ),
                            DarkStatusChip(value: items[index].currentStatus),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_driverSummary(items[index]), style: const TextStyle(color: DarkColors.muted, height: 1.3)),
                        ),
                        onTap: () => context.push(
                          admin ? AppRoutes.adminDriverOps(items[index].driverId) : AppRoutes.managerDriverOps(items[index].driverId),
                        ),
                      ),
                    ],
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

class _VehicleFuelRow extends StatelessWidget {
  const _VehicleFuelRow({required this.vehicle});

  final FuelVehicleTotal vehicle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DarkColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DarkColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined, color: DarkColors.muted, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle.vehicleNumber, style: const TextStyle(color: DarkColors.text, fontWeight: FontWeight.w700)),
                Text('${vehicle.liters} L', style: const TextStyle(color: DarkColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Text(formatInr(vehicle.totalCost), style: const TextStyle(color: DarkColors.text, fontWeight: FontWeight.w700)),
        ],
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

String _driverSummary(DriverPerformance driver) {
  final finished = driver.completedDeliveries + driver.failedDeliveries;
  if (finished == 0) {
    if (driver.activeDeliveryCount > 0) {
      final jobs = driver.activeDeliveryCount == 1 ? '1 active delivery' : '${driver.activeDeliveryCount} active deliveries';
      return '$jobs · no finished deliveries';
    }
    return 'No finished deliveries';
  }
  final rate = _rate(driver.completionRate);
  return '${driver.completedDeliveries} completed · ${driver.failedDeliveries} failed · $rate completion';
}
