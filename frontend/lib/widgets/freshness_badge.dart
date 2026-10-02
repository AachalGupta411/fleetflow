import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'status_badge.dart';

class FreshnessBadge extends StatelessWidget {
  const FreshnessBadge({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final color = switch (value) {
      'LIVE' => AppColors.success,
      'RECENT' => AppColors.blue,
      'STALE' => AppColors.warning,
      _ => AppColors.muted,
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
