import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/shipment.dart';
import '../../models/tracking.dart';
import '../../providers/auth_provider.dart';
import '../../providers/logistics_providers.dart';
import '../../providers/tracking_providers.dart';
import '../../widgets/async_view.dart';
import '../../widgets/fleet_scaffold.dart';
import '../../widgets/shipment_tile.dart';
import '../../widgets/status_badge.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final shipments = ref.watch(shipmentListProvider);
    return FleetScaffold(
      title: 'Shipments',
      body: AsyncView<List<Shipment>>(
        value: shipments,
        onRetry: () => ref.invalidate(shipmentListProvider),
        data: (items) {
          final activeCount = items.where((item) => item.isActive).length;
          final recent = items.take(5).toList();
          final featured = _featured(items);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(shipmentListProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => context.push(AppRoutes.customerAlerts),
                    child: const Text('Alerts'),
                  ),
                ),
                Text(
                  'Hello, ${user?.name ?? 'there'}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFFF5F7FB),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: StatCard(label: 'Shipments', value: '${items.length}')),
                    const SizedBox(width: 12),
                    Expanded(child: StatCard(label: 'Active', value: '$activeCount')),
                  ],
                ),
                const SizedBox(height: 20),
                const _Heading('Active shipment'),
                const SizedBox(height: 8),
                if (featured == null)
                  const _QuietCard(
                    title: 'No active shipments',
                    body: 'Your active shipments will appear here.',
                  )
                else
                  _ActiveShipmentCard(shipment: featured),
                const SizedBox(height: 20),
                const _Heading('Delivery overview'),
                const SizedBox(height: 8),
                _Overview(
                  pending: items.where((item) => item.status == 'PENDING').length,
                  inTransit: items.where((item) => item.status == 'IN_TRANSIT').length,
                  delivered: items.where((item) => item.status == 'DELIVERED').length,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: _Heading('Recent shipments')),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.customerShipments),
                      child: const Text('View all'),
                    ),
                  ],
                ),
                if (recent.isEmpty)
                  const _QuietCard(
                    title: "You don't have any shipments yet.",
                    body: 'Create your first shipment to start tracking your delivery.',
                  )
                else
                  for (final shipment in recent)
                    ShipmentTile(
                      shipment: shipment,
                      showDate: true,
                      onTap: () => context.push(AppRoutes.customerShipment(shipment.id)),
                    ),
                const SizedBox(height: 8),
                const _Heading('Quick actions'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.customerShipmentNew),
                      icon: const Icon(Icons.add),
                      label: const Text('Create shipment'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.push(AppRoutes.customerShipments),
                      child: const Text('View all shipments'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.push(AppRoutes.customerAlerts),
                      child: const Text('Alerts'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

Shipment? _featured(List<Shipment> items) {
  const order = ['IN_TRANSIT', 'ARRIVING', 'PICKED_UP', 'ASSIGNED', 'PENDING'];
  final active = items.where((item) => item.isActive).toList();
  if (active.isEmpty) {
    return null;
  }
  active.sort((a, b) {
    final aRank = order.indexOf(a.status);
    final bRank = order.indexOf(b.status);
    return (aRank < 0 ? 99 : aRank).compareTo(bRank < 0 ? 99 : bRank);
  });
  return active.first;
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFFF5F7FB)),
    );
  }
}

class _QuietCard extends StatelessWidget {
  const _QuietCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(color: AppColors.muted, height: 1.35)),
          ],
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.pending, required this.inTransit, required this.delivered});

  final int pending;
  final int inTransit;
  final int delivered;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 520;
        final cards = [
          StatCard(label: 'Pending', value: '$pending'),
          StatCard(label: 'In transit', value: '$inTransit'),
          StatCard(label: 'Delivered', value: '$delivered'),
        ];
        if (stacked) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 12),
              cards[2],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              Expanded(child: cards[index]),
            ],
          ],
        );
      },
    );
  }
}

class _ActiveShipmentCard extends ConsumerWidget {
  const _ActiveShipmentCard({required this.shipment});

  final Shipment shipment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(shipmentTrackingProvider(shipment.id));
    final eta = tracking.asData?.value;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    shipment.trackingNumber,
                    style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                StatusBadge(value: shipment.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${shipment.pickupAddress} → ${shipment.deliveryAddress}',
              style: const TextStyle(color: AppColors.ink, height: 1.35),
            ),
            const SizedBox(height: 12),
            _Fact('Priority', prettyLabel(shipment.priority)),
            if (shipment.driverName != null) _Fact('Assigned driver', shipment.driverName!),
            if (shipment.vehicleNumber != null) _Fact('Vehicle', shipment.vehicleNumber!),
            if (_etaLabel(eta) != null) _Fact('ETA', _etaLabel(eta)!),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: () => context.push(AppRoutes.customerTracking(shipment.id)),
                child: const Text('Track shipment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

String? _etaLabel(ShipmentTracking? tracking) {
  if (tracking == null) {
    return null;
  }
  final seconds = tracking.durationSeconds;
  if (seconds != null) {
    final minutes = (seconds / 60).round();
    if (minutes < 1) {
      return 'Under 1 min';
    }
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours hr' : '$hours hr $rest min';
  }
  if (tracking.eta != null) {
    return formatClock(tracking.eta!);
  }
  return null;
}
