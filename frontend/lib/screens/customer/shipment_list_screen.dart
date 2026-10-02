import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../models/shipment.dart';
import '../../providers/logistics_providers.dart';
import '../../widgets/async_view.dart';
import '../../widgets/fleet_scaffold.dart';
import '../../widgets/shipment_tile.dart';

class ShipmentListScreen extends ConsumerWidget {
  const ShipmentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shipments = ref.watch(shipmentListProvider);
    return FleetScaffold(
      title: 'All shipments',
      body: AsyncView<List<Shipment>>(
        value: shipments,
        onRetry: () => ref.invalidate(shipmentListProvider),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyPane(message: 'No shipments yet.');
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(shipmentListProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final shipment in items)
                  ShipmentTile(
                    shipment: shipment,
                    onTap: () => context.push(AppRoutes.customerShipment(shipment.id)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
