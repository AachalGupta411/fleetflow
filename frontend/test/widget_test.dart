import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleetflow/main.dart';
import 'package:fleetflow/models/health_status.dart';
import 'package:fleetflow/providers/health_provider.dart';
import 'package:fleetflow/screens/auth/login_screen.dart';

void main() {
  testWidgets('landing screen shows FleetFlow and a connected database', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthStatusProvider.overrideWith((ref) async {
            return const HealthStatus(
              status: 'ok',
              service: 'FleetFlow API',
              database: 'connected',
            );
          }),
        ],
        child: const FleetFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FleetFlow'), findsOneWidget);
    expect(find.text('Smart Logistics & Fleet Management'), findsOneWidget);
    expect(find.text('Database connected'), findsOneWidget);
    expect(find.text('Sign in to open your workspace.'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('landing screen shows a disconnected database', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthStatusProvider.overrideWith((ref) async {
            return const HealthStatus(
              status: 'unavailable',
              service: 'FleetFlow API',
              database: 'disconnected',
            );
          }),
        ],
        child: const FleetFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Database disconnected'), findsOneWidget);
    expect(find.text('Database connected'), findsNothing);
  });

  testWidgets('login form asks for an email and password', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pumpAndSettle();

    final signIn = find.widgetWithText(FilledButton, 'Sign in');
    await tester.ensureVisible(signIn);
    await tester.tap(signIn);
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });
}
