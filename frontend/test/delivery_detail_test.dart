import 'package:fleetflow/models/shipment.dart';
import 'package:fleetflow/providers/logistics_providers.dart';
import 'package:fleetflow/screens/driver/delivery_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('in-transit delivery groups route, details, and distinct actions', (tester) async {
    const shipment = Shipment(
      id: 's1',
      trackingNumber: 'FF-2026-000009',
      customerId: 'c1',
      customerName: 'Cara Customer',
      pickupAddress: 'govandi',
      deliveryAddress: 'kharghat',
      packageDescription: 'plants',
      priority: 'EXPRESS',
      status: 'IN_TRANSIT',
      vehicleNumber: 'MH12AB1001',
    );

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shipmentProvider('s1').overrideWith((ref) async => shipment),
          shipmentListProvider.overrideWith((ref) async => const [shipment]),
        ],
        child: const MaterialApp(home: DeliveryDetailScreen(shipmentId: 's1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FF-2026-000009'), findsWidgets);
    expect(find.text('Route'), findsOneWidget);
    expect(find.text('Shipment'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
    expect(find.text('Mark arriving'), findsOneWidget);
    expect(find.text('Mark arrived'), findsOneWidget);
    expect(find.text('Report failed delivery'), findsOneWidget);
    expect(find.text('Actions'), findsOneWidget);
  });
}
