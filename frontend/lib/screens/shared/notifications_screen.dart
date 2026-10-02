import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../services/delivery_service.dart';
import '../../widgets/fleet_scaffold.dart';

final notificationListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(deliveryServiceProvider).notifications();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notificationListProvider);
    return FleetScaffold(
      title: 'Alerts',
      body: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorPane(message: error.toString(), onRetry: () => ref.invalidate(notificationListProvider)),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              padding: EdgeInsets.all(16),
              children: [
                _AlertNotice(),
                SizedBox(height: 24),
                Text(
                  "You're all caught up.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 15, height: 1.4),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const _AlertNotice();
              }
              index -= 1;
              final item = items[index];
              final created = DateTime.tryParse(item['created_at'] as String? ?? '');
              return Material(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  title: Text(item['title'] as String? ?? 'Alert'),
                  subtitle: Text(
                    '${item['body'] ?? ''}\nIn-app alert. ${item['push_sent'] == true ? 'Push was sent.' : 'Push delivery is not active.'}',
                  ),
                  trailing: Text(
                    created == null ? '' : formatAgo(created),
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AlertNotice extends StatelessWidget {
  const _AlertNotice();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: AppColors.card,
      borderRadius: BorderRadius.all(Radius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'These are in-app alerts stored in FleetFlow. Phone push stays off until a Firebase service account is configured on the server. An alert here is not a device notification.',
          style: TextStyle(height: 1.35),
        ),
      ),
    );
  }
}
