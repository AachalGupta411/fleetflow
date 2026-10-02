import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/logistics_providers.dart';
import '../../widgets/dark_page.dart';

class DriversScreen extends ConsumerWidget {
  const DriversScreen({super.key, required this.createPath});

  final String createPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drivers = ref.watch(driverListProvider);
    return DarkPage(
      title: 'Drivers',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(createPath),
        backgroundColor: DarkColors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: drivers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => DarkMessage(message: error.toString(), onRetry: () => ref.invalidate(driverListProvider)),
        data: (items) {
          if (items.isEmpty) {
            return const DarkMessage(message: 'No drivers yet.');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final driver = items[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DarkColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DarkColors.line),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF243044),
                      child: Text(_initials(driver.name), style: const TextStyle(color: DarkColors.text, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(driver.name, style: const TextStyle(color: DarkColors.text, fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(driver.licenseNumber, style: const TextStyle(color: DarkColors.muted, fontSize: 13)),
                          Text(driver.email, style: const TextStyle(color: DarkColors.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                    DarkStatusChip(value: driver.status),
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

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}
