import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../models/operations.dart';
import '../../services/operations_service.dart';
import '../../widgets/fleet_scaffold.dart';

class OpsVehicleScreen extends ConsumerWidget {
  const OpsVehicleScreen({super.key, required this.vehicleId, required this.admin});

  final String vehicleId;
  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(opsVehicleProvider(vehicleId));
    return FleetScaffold(
      title: 'Vehicle',
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorPane(
          message: error.toString(),
          onRetry: () => ref.invalidate(opsVehicleProvider(vehicleId)),
        ),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(item.row.vehicleNumber, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            Text('${item.model} · ${item.row.status}'),
            if (item.row.driverName != null) Text('Driver ${item.row.driverName}'),
            if (item.row.trackingNumber != null)
              Text('Shipment ${item.row.trackingNumber} · ${item.row.shipmentStatus}'),
            Text('Odometer ${item.row.currentOdometerKm ?? 'unavailable'} km'),
            Text('Fuel type ${item.fuelType ?? 'not set'} · service ${item.row.serviceStatus}'),
            if (item.lastServiceDate != null) Text('Last service ${item.lastServiceDate}'),
            if (item.nextServiceDueKm != null) Text('Next service at ${item.nextServiceDueKm} km'),
            Text('Deliveries ${item.deliveryCount}'),
            Text('Fuel ${item.row.fuelLiters} L · ${item.row.fuelCost}'),
            const SizedBox(height: 12),
            const Text('Recent fuel', style: TextStyle(fontWeight: FontWeight.w700)),
            if (item.recentFuel.isEmpty) const Text('No fuel records yet.'),
            for (final fuel in item.recentFuel)
              Text('${fuel.fuelDate}: ${fuel.liters} L · ${fuel.totalCost}${fuel.fuelStation == null ? '' : ' · ${fuel.fuelStation}'}'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push(
                admin ? AppRoutes.adminFuel(vehicleId) : AppRoutes.managerFuel(vehicleId),
              ),
              child: const Text('Record fuel'),
            ),
          ],
        ),
      ),
    );
  }
}

final opsVehicleProvider = FutureProvider.family<VehicleOperationsView, String>((ref, id) {
  return ref.watch(operationsServiceProvider).vehicle(id);
});
