import 'package:flutter_test/flutter_test.dart';
import 'package:fleetflow/core/format.dart';

void main() {
  test('freshness thresholds match the tracking API', () {
    final now = DateTime(2026, 9, 28, 22, 0);
    expect(classifyFreshness(now.subtract(const Duration(seconds: 10)), now), 'LIVE');
    expect(classifyFreshness(now.subtract(const Duration(seconds: 90)), now), 'RECENT');
    expect(classifyFreshness(now.subtract(const Duration(minutes: 5)), now), 'STALE');
    expect(classifyFreshness(now.subtract(const Duration(minutes: 30)), now), 'OFFLINE');
    expect(classifyFreshness(null, now), 'OFFLINE');
  });
}
