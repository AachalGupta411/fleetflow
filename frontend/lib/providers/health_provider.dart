import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/health_status.dart';
import '../services/health_service.dart';
import 'api_providers.dart';

final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService(ref.watch(apiClientProvider));
});

final healthStatusProvider = FutureProvider<HealthStatus>((ref) async {
  return ref.watch(healthServiceProvider).fetch();
});
