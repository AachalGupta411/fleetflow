import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/shipment.dart';
import '../../providers/logistics_providers.dart';
import '../../services/logistics_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/fleet_scaffold.dart';
import '../../widgets/status_badge.dart';

class CustomerShipmentScreen extends ConsumerWidget {
  const CustomerShipmentScreen({super.key, required this.shipmentId});

  final String shipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shipment = ref.watch(shipmentProvider(shipmentId));
    return FleetScaffold(
      title: 'Shipment',
      body: AsyncView<Shipment>(
        value: shipment,
        onRetry: () => ref.invalidate(shipmentProvider(shipmentId)),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DetailCard(shipment: item),
            if (item.podAvailable) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.push(AppRoutes.customerProof(item.id)),
                child: const Text('View proof of delivery'),
              ),
            ],
            if (item.assignedDriverId != null &&
                const {'ASSIGNED', 'PICKED_UP', 'IN_TRANSIT', 'ARRIVING'}.contains(item.status)) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.push(AppRoutes.customerTracking(item.id)),
                child: const Text('Track driver'),
              ),
            ],
            if (item.status == 'PENDING') ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _cancel(context, ref, item.id),
                child: const Text('Cancel shipment'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(logisticsServiceProvider).updateStatus(shipmentId: id, status: 'CANCELLED');
      ref.invalidate(shipmentProvider(id));
      ref.invalidate(shipmentListProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.shipment});

  final Shipment shipment;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
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
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                StatusBadge(value: shipment.status),
              ],
            ),
            const SizedBox(height: 12),
            _Line('Priority', prettyLabel(shipment.priority)),
            _Line('Pickup', shipment.pickupAddress),
            _Line('Delivery', shipment.deliveryAddress),
            _Line('Package', shipment.packageDescription),
            if (shipment.driverName != null) _Line('Driver', shipment.driverName!),
            if (shipment.vehicleNumber != null) _Line('Vehicle', shipment.vehicleNumber!),
            if (shipment.recipientName != null) _Line('Recipient', shipment.recipientName!),
            if (shipment.deliveredAt != null) _Line('Delivered', formatClock(shipment.deliveredAt!)),
            if (shipment.failedAt != null) _Line('Failed', formatClock(shipment.failedAt!)),
            if (shipment.failureCode != null) _Line('Failure', prettyLabel(shipment.failureCode!)),
            if (shipment.failureNotes != null) _Line('Failure notes', shipment.failureNotes!),
            if (shipment.failureReason != null && shipment.failureCode == null) _Line('Failure', shipment.failureReason!),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: AppColors.ink, height: 1.35)),
        ],
      ),
    );
  }
}
