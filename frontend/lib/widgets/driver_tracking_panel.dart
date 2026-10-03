import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme/app_theme.dart';
import '../models/shipment.dart';
import '../providers/tracking_providers.dart';
import 'freshness_badge.dart';

class DriverTrackingPanel extends ConsumerWidget {
  const DriverTrackingPanel({super.key, required this.shipment});

  final Shipment shipment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(trackingSessionProvider);
    final trackable = trackableStatuses.contains(shipment.status);
    final freshness = session.lastSentAt == null
        ? 'OFFLINE'
        : classifyFreshness(session.lastSentAt);
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Location sharing', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (trackable) FreshnessBadge(value: session.tracking ? freshness : 'OFFLINE'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              trackable
                  ? (session.message ?? 'Sharing your position while this delivery is active.')
                  : 'Tracking starts after you pick up this delivery.',
              style: const TextStyle(color: AppColors.ink, height: 1.35),
            ),
            if (session.lastError != null) ...[
              const SizedBox(height: 8),
              Text(session.lastError!, style: const TextStyle(color: AppColors.danger)),
            ],
            if (session.lastSentAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last location update: ${formatAgo(session.lastSentAt!)}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
            if (session.latitude != null && session.longitude != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last fix ${session.latitude!.toStringAsFixed(5)}, ${session.longitude!.toStringAsFixed(5)}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
            if (session.permission == 'denied' ||
                session.permission == 'deniedForever' ||
                session.permission == 'disabled') ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(trackingSessionProvider.notifier).openSettings(),
                child: Text(
                  session.permission == 'disabled' ? 'Turn on location' : 'Open settings',
                ),
              ),
            ],
            if (trackable) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: session.tracking
                    ? OutlinedButton(
                        onPressed: () => ref.read(trackingSessionProvider.notifier).pause(),
                        child: const Text('Stop tracking'),
                      )
                    : FilledButton(
                        onPressed: () => ref.read(trackingSessionProvider.notifier).resume(),
                        child: const Text('Start tracking'),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
