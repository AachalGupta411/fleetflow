/// Same thresholds as the API freshness classifier.
const int liveSeconds = 45;
const int recentSeconds = 180;
const int staleSeconds = 900;

String classifyFreshness(DateTime? timestamp, [DateTime? now]) {
  if (timestamp == null) {
    return 'OFFLINE';
  }
  final age = (now ?? DateTime.now()).difference(timestamp.toLocal()).inSeconds;
  if (age <= liveSeconds) {
    return 'LIVE';
  }
  if (age <= recentSeconds) {
    return 'RECENT';
  }
  if (age <= staleSeconds) {
    return 'STALE';
  }
  return 'OFFLINE';
}

String formatClock(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String formatAgo(DateTime value) {
  final seconds = DateTime.now().difference(value.toLocal()).inSeconds;
  if (seconds < 10) {
    return 'Just now';
  }
  if (seconds < 60) {
    return '$seconds seconds ago';
  }
  final minutes = seconds ~/ 60;
  if (minutes < 60) {
    return minutes == 1 ? '1 minute ago' : '$minutes minutes ago';
  }
  final hours = minutes ~/ 60;
  if (hours < 24) {
    return hours == 1 ? '1 hour ago' : '$hours hours ago';
  }
  final days = hours ~/ 24;
  return days == 1 ? '1 day ago' : '$days days ago';
}

String formatDistance(int meters) {
  if (meters < 1000) {
    return '$meters m';
  }
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
