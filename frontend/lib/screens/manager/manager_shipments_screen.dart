import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../providers/logistics_providers.dart';
import '../../widgets/dark_page.dart';
import '../../widgets/status_badge.dart';

class ManagerShipmentsScreen extends ConsumerWidget {
  const ManagerShipmentsScreen({super.key, this.admin = false});

  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shipments = ref.watch(shipmentListProvider);
    return DarkPage(
      title: 'Shipments',
      body: shipments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => DarkMessage(message: error.toString(), onRetry: () => ref.invalidate(shipmentListProvider)),
        data: (items) {
          if (items.isEmpty) {
            return const DarkMessage(message: 'No shipments yet.');
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(shipmentListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final shipment = items[index];
                final detail = [
                  shipment.customerName,
                  prettyLabel(shipment.priority),
                  if (shipment.driverName != null) shipment.driverName!,
                  if (shipment.vehicleNumber != null) shipment.vehicleNumber!,
                ].join(' · ');
                return Material(
                  color: DarkColors.card,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.push(admin ? AppRoutes.adminShipment(shipment.id) : AppRoutes.managerShipment(shipment.id)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(shipment.trackingNumber, style: const TextStyle(color: DarkColors.text, fontWeight: FontWeight.w800, fontSize: 16)),
                                const SizedBox(height: 6),
                                Text(shipment.deliveryAddress, style: const TextStyle(color: DarkColors.text, height: 1.35)),
                                const SizedBox(height: 6),
                                Text(detail, style: const TextStyle(color: DarkColors.muted, fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          DarkStatusChip(value: shipment.status),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
