import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/delivery_rules.dart';
import '../../core/maps_link.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/shipment.dart';
import '../../providers/delivery_providers.dart';
import '../../providers/logistics_providers.dart';
import '../../services/delivery_service.dart';
import '../../services/logistics_service.dart';
import '../../providers/tracking_providers.dart';
import '../../widgets/async_view.dart';
import '../../widgets/dark_page.dart';
import '../../widgets/delivery_progress.dart';
import '../../widgets/driver_tracking_panel.dart';
import '../../widgets/fleet_scaffold.dart';
import '../../widgets/status_badge.dart';

class DeliveryDetailScreen extends ConsumerWidget {
  const DeliveryDetailScreen({super.key, required this.shipmentId});

  final String shipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(trackingBinderProvider);
    final shipment = ref.watch(shipmentProvider(shipmentId));
    return FleetScaffold(
      title: 'Delivery',
      body: AsyncView<Shipment>(
        value: shipment,
        onRetry: () => ref.invalidate(shipmentProvider(shipmentId)),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DarkSection(
              title: item.trackingNumber,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge(value: item.status),
                  const SizedBox(height: 14),
                  DeliveryProgress(status: item.status, arrived: item.geofenceEnteredAt != null),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DriverTrackingPanel(shipment: item),
            const SizedBox(height: 12),
            DarkSection(
              title: 'Route',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Fact(Icons.trip_origin, 'Pickup', item.pickupAddress),
                  const SizedBox(height: 12),
                  _Fact(Icons.flag_outlined, 'Destination', item.deliveryAddress),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => _navigate(context, item),
                    icon: const Icon(Icons.navigation_outlined, size: 18),
                    label: const Text('Navigate'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DarkSection(
              title: 'Shipment',
              child: Column(
                children: [
                  _Fact(Icons.flag_circle_outlined, 'Priority', prettyLabel(item.priority)),
                  const SizedBox(height: 12),
                  _Fact(Icons.inventory_2_outlined, 'Package', item.packageDescription),
                  if (item.vehicleNumber != null) ...[
                    const SizedBox(height: 12),
                    _Fact(Icons.local_shipping_outlined, 'Vehicle', item.vehicleNumber!),
                  ],
                  if (item.failureReason != null) ...[
                    const SizedBox(height: 12),
                    _Fact(Icons.report_outlined, 'Failure reason', item.failureReason!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            ..._actions(context, ref, item),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref, Shipment item) {
    final next = switch (item.status) {
      'ASSIGNED' => ['PICKED_UP'],
      'PICKED_UP' => ['IN_TRANSIT'],
      'IN_TRANSIT' => ['ARRIVING'],
      _ => <String>[],
    };
    final canFinish = item.status == 'IN_TRANSIT' || item.status == 'ARRIVING';
    final buttons = <Widget>[
      for (final status in next)
        FilledButton(
          onPressed: () => _update(context, ref, item.id, status),
          child: Text(_actionLabel(status)),
        ),
      if (canFinish && item.geofenceEnteredAt == null)
        FilledButton.tonal(
          onPressed: () => _arrive(context, ref, item),
          child: const Text('Mark arrived'),
        ),
      if (item.status == 'ARRIVING')
        FilledButton(
          onPressed: () => context.push(AppRoutes.driverPod(item.id)),
          child: const Text('Proof of delivery'),
        ),
      if (canFinish)
        OutlinedButton(
          onPressed: () => context.push(AppRoutes.driverFail(item.id)),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: DarkColors.line)),
          child: const Text('Report failed delivery'),
        ),
    ];
    if (buttons.isEmpty) {
      return const [];
    }
    return [
      DarkSection(
        title: 'Actions',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (canFinish && item.geofenceEnteredAt == null) ...[
              Text(
                'Mark arrived checks your GPS against a $defaultGeofenceRadiusMeters m zone around the destination.',
                style: const TextStyle(color: AppColors.muted, height: 1.35),
              ),
              const SizedBox(height: 12),
            ],
            for (var index = 0; index < buttons.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              buttons[index],
            ],
          ],
        ),
      ),
    ];
  }

  String _actionLabel(String status) {
    return switch (status) {
      'PICKED_UP' => 'Mark picked up',
      'IN_TRANSIT' => 'Start delivery',
      'ARRIVING' => 'Mark arriving',
      _ => prettyLabel(status),
    };
  }

  Future<void> _arrive(BuildContext context, WidgetRef ref, Shipment item) async {
    final deliveryId = item.deliveryId;
    if (deliveryId == null) {
      return;
    }
    final fix = await ref.read(trackingSessionProvider.notifier).captureFix();
    if (fix == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turn on location before marking arrival.')),
        );
      }
      return;
    }
    String zone = 'Inside the delivery zone.';
    if (item.deliveryLatitude != null && item.deliveryLongitude != null) {
      final meters = distanceMeters(fix.latitude, fix.longitude, item.deliveryLatitude!, item.deliveryLongitude!).round();
      final inside = insideGeofence(meters.toDouble(), defaultGeofenceRadiusMeters);
      if (!inside) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Outside the delivery zone. You are $meters m away. Arrival is accepted within $defaultGeofenceRadiusMeters m.',
              ),
            ),
          );
        }
        return;
      }
      zone = 'Inside the $defaultGeofenceRadiusMeters m delivery zone ($meters m away).';
    }
    try {
      final queued = await ref.read(deliveryServiceProvider).arrive(
            deliveryId: deliveryId,
            latitude: fix.latitude,
            longitude: fix.longitude,
            accuracy: fix.accuracy,
          );
      ref.read(pendingActionsProvider.notifier).setCount(await ref.read(deliveryServiceProvider).pendingCount());
      ref.invalidate(shipmentProvider(item.id));
      ref.invalidate(shipmentListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              queued ? 'Arrival saved on this device. It will sync when the connection returns.' : '$zone Arrival recorded.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _navigate(BuildContext context, Shipment item) async {
    final opened = await openDrivingDirections(
      latitude: item.deliveryLatitude,
      longitude: item.deliveryLongitude,
      address: item.deliveryAddress,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps for this destination.')),
      );
    }
  }

  Future<void> _update(BuildContext context, WidgetRef ref, String id, String status) async {
    try {
      await ref.read(logisticsServiceProvider).updateStatus(shipmentId: id, status: status);
      ref.invalidate(shipmentProvider(id));
      ref.invalidate(shipmentListProvider);
      ref.invalidate(myDriverProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: AppColors.ink, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}
