/// Delivery duration is delivered_at minus picked_up_at, in minutes.
/// Missing timestamps stay unavailable. Failed deliveries are not given a duration.
double? deliveryDurationMinutes(DateTime? pickedUpAt, DateTime? deliveredAt) {
  if (pickedUpAt == null || deliveredAt == null) {
    return null;
  }
  final minutes = deliveredAt.difference(pickedUpAt).inSeconds / 60;
  if (minutes < 0) {
    return null;
  }
  return double.parse(minutes.toStringAsFixed(1));
}

/// Completion and failure rates over finished deliveries. Null when none are finished.
({double? completion, double? failure}) outcomeRates(int completed, int failed) {
  final finished = completed + failed;
  if (finished == 0) {
    return (completion: null, failure: null);
  }
  return (
    completion: double.parse((completed / finished).toStringAsFixed(4)),
    failure: double.parse((failed / finished).toStringAsFixed(4)),
  );
}

bool canViewOperations(String role) {
  return role == 'ADMIN' || role == 'FLEET_MANAGER';
}

enum AnalyticsPreset { last7, last30, last90 }

class DateWindow {
  const DateWindow({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  static DateWindow preset(AnalyticsPreset preset, DateTime now) {
    final end = DateTime(now.year, now.month, now.day);
    final days = switch (preset) {
      AnalyticsPreset.last7 => 7,
      AnalyticsPreset.last30 => 30,
      AnalyticsPreset.last90 => 90,
    };
    return DateWindow(from: end.subtract(Duration(days: days - 1)), to: end);
  }

  String get query {
    return 'from=${_iso(from)}&to=${_iso(to)}';
  }
}

String _iso(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

num? parseAmount(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value;
  }
  return num.tryParse(value.toString());
}
