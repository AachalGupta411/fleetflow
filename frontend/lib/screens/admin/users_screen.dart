import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/logistics_providers.dart';
import '../../services/logistics_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/fleet_scaffold.dart';
import '../../widgets/status_badge.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(userListProvider);
    return FleetScaffold(
      title: 'Users',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.adminUserNew),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: AsyncView<List<AppUserRecord>>(
        value: users,
        onRetry: () => ref.invalidate(userListProvider),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyPane(message: 'No users yet.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = items[index];
              return Material(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  title: Text(user.name),
                  subtitle: Text(user.email),
                  trailing: StatusBadge(value: user.role),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
