import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../models/operations.dart';
import '../../services/operations_service.dart';
import '../../widgets/fleet_scaffold.dart';

class FleetBoardScreen extends ConsumerStatefulWidget {
  const FleetBoardScreen({super.key, required this.admin});

  final bool admin;

  @override
  ConsumerState<FleetBoardScreen> createState() => _FleetBoardScreenState();
}

class _FleetBoardScreenState extends ConsumerState<FleetBoardScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final fleet = ref.watch(fleetBoardProvider(_status));
    return FleetScaffold(
      title: 'Fleet board',
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                for (final choice in const [null, 'AVAILABLE', 'ASSIGNED', 'ON_DELIVERY', 'INACTIVE'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(choice ?? 'All'),
                      selected: _status == choice,
                      onSelected: (_) => setState(() => _status = choice),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: fleet.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorPane(
                message: error.toString(),
                onRetry: () => ref.invalidate(fleetBoardProvider(_status)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyPane(message: 'No vehicles in this filter.');
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(fleetBoardProvider(_status)),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final item in items)
                        Card(
                          child: ListTile(
                            title: Text(item.vehicleNumber),
                            subtitle: Text(
                              [
                                item.status,
                                if (item.driverName != null) item.driverName!,
                                if (item.trackingNumber != null) item.trackingNumber!,
                                if (item.shipmentStatus != null) item.shipmentStatus!,
                                'Fuel ${item.fuelCost}',
                                'Service ${item.serviceStatus}',
                              ].join(' · '),
                            ),
                            onTap: () => context.push(
                              widget.admin
                                  ? AppRoutes.adminVehicleOps(item.vehicleId)
                                  : AppRoutes.managerVehicleOps(item.vehicleId),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final fleetBoardProvider = FutureProvider.family<List<FleetVehicleRow>, String?>((ref, status) {
  return ref.watch(operationsServiceProvider).fleet(status: status);
});
