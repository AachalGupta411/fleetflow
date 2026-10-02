import '../core/network/api_client.dart';
import '../models/health_status.dart';

class HealthService {
  HealthService(this._client);

  final ApiClient _client;

  Future<HealthStatus> fetch() async {
    final json = await _client.get('/health');
    return HealthStatus.fromJson(json);
  }
}
