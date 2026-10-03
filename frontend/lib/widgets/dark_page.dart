import 'package:flutter/material.dart';

import 'status_badge.dart';

class DarkColors {
  static const bg = Color(0xFF10141C);
  static const panel = Color(0xFF171C26);
  static const card = Color(0xFF1E2531);
  static const line = Color(0xFF2C3544);
  static const text = Color(0xFFF5F7FB);
  static const muted = Color(0xFF9AA6B8);
  static const blue = Color(0xFF2563EB);
}

class DarkPage extends StatelessWidget {
  const DarkPage({super.key, required this.title, required this.body, this.floatingActionButton});

  final String title;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: AppBar(
        backgroundColor: DarkColors.panel,
        foregroundColor: DarkColors.text,
        title: Text(title),
      ),
      floatingActionButton: floatingActionButton,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: body,
        ),
      ),
    );
  }
}

class DarkStatusChip extends StatelessWidget {
  const DarkStatusChip({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (value) {
      'DELIVERED' || 'AVAILABLE' => (const Color(0xFF14532D), const Color(0xFF86EFAC)),
      'FAILED' || 'CANCELLED' || 'INACTIVE' => (const Color(0xFF7F1D1D), const Color(0xFFFECACA)),
      'PENDING' || 'MAINTENANCE' => (const Color(0xFF713F12), const Color(0xFFFDE68A)),
      _ => (const Color(0xFF1E3A8A), const Color(0xFFBFDBFE)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(prettyLabel(value), style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class DarkSection extends StatelessWidget {
  const DarkSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DarkColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: DarkColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: DarkColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Equal-width metric tiles that drop to two columns on a phone.
class MetricRow extends StatelessWidget {
  const MetricRow({super.key, required this.items});

  final List<MetricTile> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520 ? 2 : items.length;
        final width = (constraints.maxWidth - (12 * (columns - 1))) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items) SizedBox(width: width, child: item),
          ],
        );
      },
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DarkColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DarkColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(color: DarkColors.text, fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: DarkColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class BlockLabel extends StatelessWidget {
  const BlockLabel(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(color: DarkColors.text, fontWeight: FontWeight.w700))),
        if (trailing != null) Text(trailing!, style: const TextStyle(color: DarkColors.muted, fontSize: 13)),
      ],
    );
  }
}

class DarkMessage extends StatelessWidget {
  const DarkMessage({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: DarkColors.muted, height: 1.4)),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
