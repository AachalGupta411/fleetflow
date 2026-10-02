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
