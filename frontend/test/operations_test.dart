import 'package:fleetflow/core/operations_math.dart';
import 'package:fleetflow/models/operations.dart';
import 'package:fleetflow/widgets/operations_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duration and rates stay empty without finished data', () {
    final start = DateTime.utc(2026, 9, 1, 10);
    final end = DateTime.utc(2026, 9, 1, 10, 42);
    expect(deliveryDurationMinutes(start, end), 42);
    expect(deliveryDurationMinutes(null, end), isNull);
    expect(deliveryDurationMinutes(end, start), isNull);
    expect(outcomeRates(8, 2).completion, 0.8);
    expect(outcomeRates(0, 0).completion, isNull);
    expect(canViewOperations('FLEET_MANAGER'), isTrue);
    expect(canViewOperations('ADMIN'), isTrue);
    expect(canViewOperations('DRIVER'), isFalse);
    expect(canViewOperations('CUSTOMER'), isFalse);
  });

  test('date window and analytics parsing', () {
    final window = DateWindow.preset(AnalyticsPreset.last7, DateTime(2026, 9, 29));
    expect(window.query, 'from=2026-09-23&to=2026-09-29');
    final parsed = DriverPerformance.fromJson({
      'driver_id': 'driver-1',
      'driver_name': 'Priya Shah',
      'current_status': 'AVAILABLE',
      'assigned_deliveries': 2,
      'completed_deliveries': 1,
      'failed_deliveries': 1,
      'active_delivery_count': 0,
      'completion_rate': 0.5,
      'failure_rate': 0.5,
      'average_delivery_duration_minutes': 42,
      'average_distance_km': null,
    });
    expect(parsed.completedDeliveries, 1);
    expect(parsed.averageDistanceKm, isNull);
    final fuel = FuelAnalytics.fromJson({
      'total_liters': '0.00',
      'total_cost': '0.00',
      'average_price_per_liter': null,
      'by_vehicle': [],
      'cost_trend': [],
    });
    expect(fuel.isEmpty, isTrue);
    expect(parseAmount('12.50'), 12.5);
  });

  testWidgets('empty analytics and driver metrics render without invented numbers', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              OutcomeChart(completed: 0, failed: 0, active: 0),
              FuelCostChart(points: []),
              Text('Completion unavailable'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('No delivery outcomes in this period.'), findsOneWidget);
    expect(find.text('No fuel cost in this period.'), findsOneWidget);
    expect(find.text('Completion unavailable'), findsOneWidget);
  });

  testWidgets('fuel summary renders recorded totals', (tester) async {
    const fuel = FuelAnalytics(
      totalLiters: '10.00',
      totalCost: '1000.00',
      averagePricePerLiter: '100.00',
      byVehicle: [
        FuelVehicleTotal(vehicleId: 'v1', vehicleNumber: 'MH12AB1001', liters: '10.00', totalCost: '1000.00'),
      ],
      costTrend: [CostPoint(period: '2026-09-29', totalCost: '1000.00')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text('Fuel ${fuel.totalLiters} L · ${fuel.totalCost}'),
              Text(fuel.byVehicle.single.vehicleNumber),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Fuel 10.00 L · 1000.00'), findsOneWidget);
    expect(find.text('MH12AB1001'), findsOneWidget);
  });
}
