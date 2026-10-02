/// User-facing text for API failures. Server messages are kept when they are short and safe.
String friendlyApiMessage({int? statusCode, String? serverDetail, bool network = false}) {
  if (network) {
    return 'Unable to connect to FleetFlow. Your offline actions will be synchronized when the connection returns.';
  }
  final detail = serverDetail?.trim();
  if (detail != null && detail.isNotEmpty && !_looksTechnical(detail)) {
    return detail;
  }
  switch (statusCode) {
    case 400:
      return 'Check the information and try again.';
    case 401:
      return 'Your session expired. Sign in again.';
    case 403:
      return "You don't have permission to perform this action.";
    case 404:
      return 'That record could not be found.';
    case 409:
      return 'This record has already been updated.';
    case 422:
      return 'Check the information and try again.';
    default:
      return 'FleetFlow could not complete that request.';
  }
}

bool _looksTechnical(String value) {
  final lower = value.toLowerCase();
  return value.length > 400 ||
      lower.contains('traceback') ||
      lower.contains('sqlalchemy') ||
      lower.contains('password_hash');
}
