import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/sync_status.dart';
import '../../core/theme/app_theme.dart';
import '../../models/driver_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_providers.dart';
import '../../providers/logistics_providers.dart';
import '../../providers/tracking_providers.dart';
import '../../services/delivery_service.dart';
import '../../widgets/fleet_scaffold.dart';
import '../../widgets/shipment_tile.dart';
import '../../widgets/status_badge.dart';

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(trackingBinderProvider);
    final online = ref.watch(onlineProvider).value ?? true;
    final pending = ref.watch(pendingActionsProvider);
    final phase = ref.watch(syncPhaseProvider);
    ref.watch(pendingCountLoaderProvider);
    ref.listen(onlineProvider, (previous, next) {
      if (next.value != true) {
        return;
      }
      ref.read(syncPhaseProvider.notifier).setPhase(SyncPhase.syncing);
      ref.read(deliveryServiceProvider).flush().then((synced) async {
        final left = await ref.read(deliveryServiceProvider).pendingCount();
        ref.read(pendingActionsProvider.notifier).setCount(left);
        ref.read(syncPhaseProvider.notifier).setPhase(left > 0 ? SyncPhase.failed : SyncPhase.idle);
        if (synced > 0) {
          ref.invalidate(shipmentListProvider);
        }
      }).catchError((_) {
        ref.read(syncPhaseProvider.notifier).setPhase(SyncPhase.failed);
      });
    });
    final user = ref.watch(authProvider).user;
    final profile = ref.watch(myDriverProvider);
    final shipments = ref.watch(shipmentListProvider);
    return FleetScaffold(
      title: 'Deliveries',
      body: shipments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorPane(
          message: error.toString(),
          onRetry: () => ref.invalidate(shipmentListProvider),
        ),
        data: (items) {
          final active = items.where((item) => item.isActive).toList();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(shipmentListProvider);
              ref.invalidate(myDriverProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (connectionBanner(online: online, pending: pending, phase: phase) != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(connectionBanner(online: online, pending: pending, phase: phase)!),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => context.push(AppRoutes.driverAlerts),
                    child: const Text('Alerts'),
                  ),
                ),
                Text(
                  user?.name ?? 'Driver',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                profile.when(
                  loading: () => const Text('Loading status…'),
                  error: (error, _) => Text(error.toString()),
                  data: (driver) => _DriverStatus(driver: driver),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: StatCard(label: 'Assigned', value: '${items.length}')),
                    const SizedBox(width: 12),
                    Expanded(child: StatCard(label: 'Active', value: '${active.length}')),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Assigned deliveries',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink),
                ),
                const SizedBox(height: 12),
                if (active.isEmpty)
                  const EmptyPane(message: 'No deliveries assigned.')
                else
                  for (final shipment in active)
                    ShipmentTile(
                      shipment: shipment,
                      onTap: () => context.push(AppRoutes.driverDelivery(shipment.id)),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DriverStatus extends StatelessWidget {
  const _DriverStatus({required this.driver});

  final DriverProfile driver;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Current status', style: TextStyle(color: AppColors.muted)),
        const SizedBox(width: 8),
        StatusBadge(value: driver.status),
      ],
    );
  }
}
