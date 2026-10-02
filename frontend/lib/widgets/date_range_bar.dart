import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/operations_math.dart';
import '../providers/operations_providers.dart';

class DateRangeBar extends ConsumerWidget {
  const DateRangeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(analyticsRangeProvider);
    return SegmentedButton<AnalyticsPreset>(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF1E3A8A);
          }
          return const Color(0xFF1E2531);
        }),
        foregroundColor: const WidgetStatePropertyAll(Color(0xFFF5F7FB)),
        side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFF2C3544))),
      ),
      segments: const [
        ButtonSegment(value: AnalyticsPreset.last7, label: Text('7 days')),
        ButtonSegment(value: AnalyticsPreset.last30, label: Text('30 days')),
        ButtonSegment(value: AnalyticsPreset.last90, label: Text('90 days')),
      ],
      selected: {selected},
      onSelectionChanged: (value) => ref.read(analyticsRangeProvider.notifier).select(value.first),
    );
  }
}
