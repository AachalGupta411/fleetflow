import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

String prettyLabel(String value) {
  return value
      .split('_')
      .map((part) => part.isEmpty ? part : '${part[0]}${part.substring(1).toLowerCase()}')
      .join(' ');
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final color = switch (value) {
      'DELIVERED' || 'AVAILABLE' => AppColors.success,
      'FAILED' || 'CANCELLED' || 'INACTIVE' => AppColors.danger,
      'PENDING' || 'MAINTENANCE' || 'OFFLINE' => AppColors.warning,
      _ => AppColors.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        prettyLabel(value),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
