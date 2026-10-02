import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_config.dart';
import '../core/theme/app_theme.dart';
import '../providers/health_provider.dart';

class ConnectionStatusCard extends ConsumerWidget {
  const ConnectionStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthStatusProvider);

    final content = health.when(
      loading: () => const _StatusContent(
        label: 'Checking the API',
        color: AppColors.blue,
        icon: Icons.sync,
      ),
      error: (error, _) => _StatusContent(
        label: 'API unreachable',
        detail: _unreachableDetail(error),
        color: AppColors.danger,
        icon: Icons.cloud_off_outlined,
      ),
      data: (status) {
        if (status.isHealthy) {
          return const _StatusContent(
            label: 'Database connected',
            color: AppColors.success,
            icon: Icons.check_circle_outline,
          );
        }
        return _StatusContent(
          label: 'Database disconnected',
          detail: 'The API responded, but the database status is ${status.database}.',
          color: AppColors.danger,
          icon: Icons.error_outline,
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        content,
        TextButton(
          onPressed: health.isLoading ? null : () => ref.invalidate(healthStatusProvider),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('Check again'),
        ),
      ],
    );
  }
}

String _unreachableDetail(Object error) {
  if (!ApiConfig.hasOverride && ApiConfig.baseUrl.contains(ApiConfig.androidEmulatorHost)) {
    return 'This install is using the emulator address ${ApiConfig.baseUrl}. On a phone, rebuild with --dart-define=API_BASE_URL=http://YOUR_MAC_IP:8000 and start the API on 0.0.0.0.';
  }
  return error.toString();
}

class _StatusContent extends StatelessWidget {
  const _StatusContent({
    required this.label,
    required this.color,
    required this.icon,
    this.detail,
  });

  final String label;
  final String? detail;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFE6EDF5),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(
                  detail!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
