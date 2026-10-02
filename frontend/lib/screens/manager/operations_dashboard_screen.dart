import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../providers/operations_providers.dart';

class OperationsDashboardScreen extends ConsumerWidget {
  const OperationsDashboardScreen({super.key, required this.admin});

  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(operationsOverviewProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF10141C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171C26),
        foregroundColor: Colors.white,
        title: const Text('Operations'),
      ),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error.toString(), style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(operationsOverviewProvider), child: const Text('Retry')),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(operationsOverviewProvider),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Fleet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _StatRow([
                _Stat('Vehicles', '${data.fleet.totalVehicles}'),
                _Stat('Active', '${data.fleet.activeVehicles}'),
                _Stat('Available', '${data.fleet.availableVehicles}'),
                _Stat('On delivery', '${data.fleet.vehiclesOnDelivery}'),
              ]),
              const SizedBox(height: 16),
              const Text('Drivers', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _StatRow([
                _Stat('Drivers', '${data.fleet.totalDrivers}'),
                _Stat('Available', '${data.fleet.availableDrivers}'),
                _Stat('On delivery', '${data.fleet.driversOnDelivery}'),
              ]),
              const SizedBox(height: 16),
              const Text('Deliveries', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _StatRow([
                _Stat('Active', '${data.fleet.activeDeliveries}'),
                _Stat('Completed', '${data.fleet.completedDeliveries}'),
                _Stat('Failed', '${data.fleet.failedDeliveries}'),
                _Stat('Completion', _rate(data.fleet.completionRate)),
              ]),
              const SizedBox(height: 16),
              const Text('Fuel', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _StatRow([
                _Stat('Liters', data.fuelLiters),
                _Stat('Cost', data.fuelCost),
                _Stat('Avg / L', data.averagePricePerLiter ?? '—'),
              ]),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => context.push(admin ? AppRoutes.adminAnalytics : AppRoutes.managerAnalytics),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF2C3544))),
                child: const Text('Analytics'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.push(admin ? AppRoutes.adminBoard : AppRoutes.managerBoard),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF2C3544))),
                child: const Text('Fleet board'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.push(admin ? AppRoutes.adminPricing : AppRoutes.managerPricing),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF2C3544))),
                child: const Text('Pricing'),
              ),
            ],
          ),
        ),
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

class _StatRow extends StatelessWidget {
  const _StatRow(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 12, runSpacing: 12, children: children);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2531),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C3544)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF9AA6B8), fontSize: 13)),
        ],
      ),
    );
  }
}
