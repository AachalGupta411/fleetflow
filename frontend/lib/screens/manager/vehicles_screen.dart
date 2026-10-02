import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/logistics_providers.dart';
import '../../widgets/dark_page.dart';
import '../../widgets/status_badge.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key, required this.createPath});

  final String createPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehicleListProvider);
    return DarkPage(
      title: 'Vehicles',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(createPath),
        backgroundColor: DarkColors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: vehicles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => DarkMessage(message: error.toString(), onRetry: () => ref.invalidate(vehicleListProvider)),
        data: (items) {
          if (items.isEmpty) {
            return const DarkMessage(message: 'No vehicles yet.');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final vehicle = items[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DarkColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DarkColors.line),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF243044),
                      child: Icon(Icons.local_shipping_outlined, color: DarkColors.text),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vehicle.vehicleNumber, style: const TextStyle(color: DarkColors.text, fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('${prettyLabel(vehicle.vehicleType)} · ${vehicle.model}', style: const TextStyle(color: DarkColors.muted)),
                          Text('${vehicle.capacity} kg', style: const TextStyle(color: DarkColors.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                    DarkStatusChip(value: vehicle.status),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
