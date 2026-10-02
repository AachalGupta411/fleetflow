import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../services/delivery_service.dart';
import '../../widgets/fleet_scaffold.dart';
import '../../widgets/status_badge.dart';

final deliveryEventsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(deliveryServiceProvider).recentEvents();
});

class DeliveryEventsScreen extends ConsumerWidget {
  const DeliveryEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(deliveryEventsProvider);
    return FleetScaffold(
      title: 'Delivery activity',
      body: events.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorPane(message: error.toString(), onRetry: () => ref.invalidate(deliveryEventsProvider)),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyPane(message: 'No delivery events yet.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final created = DateTime.tryParse(item['created_at'] as String? ?? '');
              return Material(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  title: Text(prettyLabel(item['event_type'] as String? ?? 'Event')),
                  subtitle: Text(item['note'] as String? ?? 'Recorded delivery event'),
                  trailing: Text(created == null ? '' : formatAgo(created)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
