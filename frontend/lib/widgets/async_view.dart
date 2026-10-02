import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fleet_scaffold.dart';

class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.onRetry,
    required this.data,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) data;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorPane(message: error.toString(), onRetry: onRetry),
      data: data,
    );
  }
}
