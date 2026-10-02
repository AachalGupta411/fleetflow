import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tracking.dart';
import '../providers/api_providers.dart';
import '../core/network/api_client.dart';

class TrackingApi {
  TrackingApi(this._client);

  final ApiClient _client;

  Future<List<FleetDriver>> fleet() async {
    final data = await _client.send('GET', '/api/v1/tracking/fleet');
    return (data as List<dynamic>)
        .map((item) => FleetDriver.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ShipmentTracking> shipmentTracking(String shipmentId) async {
    final data = await _client.send('GET', '/api/v1/tracking/shipments/$shipmentId');
    return ShipmentTracking.fromJson(data as Map<String, dynamic>);
  }
}

final trackingApiProvider = Provider<TrackingApi>((ref) {
  return TrackingApi(ref.watch(apiClientProvider));
});
