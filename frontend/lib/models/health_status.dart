class HealthStatus {
  const HealthStatus({
    required this.status,
    required this.service,
    required this.database,
  });

  final String status;
  final String service;
  final String database;

  bool get isHealthy => status == 'ok' && database == 'connected';

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] as String? ?? 'unknown',
      service: json['service'] as String? ?? '',
      database: json['database'] as String? ?? 'unknown',
    );
  }
}
