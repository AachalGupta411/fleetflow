import 'package:fleetflow/core/maps_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('driving directions use coordinates when they exist', () {
    final uri = drivingDirectionsUri(latitude: 19.07, longitude: 72.88, address: 'Kharghar');
    expect(uri, isNotNull);
    expect(uri!.queryParameters['destination'], '19.07,72.88');
    expect(uri.queryParameters['travelmode'], 'driving');
  });

  test('driving directions fall back to the address', () {
    final uri = drivingDirectionsUri(address: 'Dombivli station');
    expect(uri!.queryParameters['destination'], 'Dombivli station');
  });

  test('an empty destination does not build a link', () {
    expect(drivingDirectionsUri(address: '   '), isNull);
  });
}
