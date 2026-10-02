import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';

void main() {
  runApp(const ProviderScope(child: FleetFlowApp()));
}

class FleetFlowApp extends ConsumerWidget {
  const FleetFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionBinderProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'FleetFlow',
      theme: buildAppTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
