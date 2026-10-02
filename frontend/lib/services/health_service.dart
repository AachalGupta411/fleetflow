import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import '../models/health_status.dart';

class HealthService {
  HealthService(this._client);

  final ApiClient _client;

  Future<HealthStatus> fetch() async {
    final baseUrl = ApiConfig.baseUrl;
    final healthUrl = baseUrl.endsWith('/api/v1')
        ? '${baseUrl.substring(0, baseUrl.length - 7)}/health'
        : '$baseUrl/health';

    final json = await _client.getAbsolute(healthUrl);
    return HealthStatus.fromJson(json);
  }
}
