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
        Wrap(
          spacing: 8,
          runSpacing: 8,
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
    final background = current
        ? AppColors.blue
        : done
        ? const Color(0xFF14532D)
        : AppColors.panel;
    final foreground = current
        ? Colors.white
        : done
        ? const Color(0xFF86EFAC)
        : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: foreground, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
