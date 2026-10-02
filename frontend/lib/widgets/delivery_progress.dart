import 'package:flutter/material.dart';

import '../core/delivery_rules.dart';
import '../core/theme/app_theme.dart';
import 'status_badge.dart';

class DeliveryProgress extends StatelessWidget {
  const DeliveryProgress({super.key, required this.status, required this.arrived});

  final String status;
  final bool arrived;

  @override
  Widget build(BuildContext context) {
    if (status == 'FAILED' || status == 'CANCELLED') {
      return StatusBadge(value: status);
    }
    final current = status == 'DELIVERED' ? deliverySteps.length - 1 : deliverySteps.indexOf(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Delivery progress', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var index = 0; index < deliverySteps.length; index++)
              _Step(
                label: prettyLabel(deliverySteps[index]),
                done: current >= index && current >= 0,
                current: index == current,
              ),
          ],
        ),
        if (arrived && status != 'DELIVERED') ...[
          const SizedBox(height: 8),
          Text(
            'Inside the $defaultGeofenceRadiusMeters m delivery zone',
            style: const TextStyle(color: AppColors.success),
          ),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.done, required this.current});

  final String label;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = current ? AppColors.ink : done ? AppColors.success : AppColors.muted;
    return Text(label, style: TextStyle(color: color, fontWeight: current ? FontWeight.w800 : FontWeight.w500, fontSize: 12));
  }
}
