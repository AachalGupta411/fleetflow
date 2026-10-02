import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Single place that decides which FleetFlow API the app calls.
///
/// Precedence:
/// 1. `--dart-define=API_BASE_URL=...` when it is set
/// 2. Flutter web: `http://127.0.0.1:8000`
/// 3. Android: `http://10.0.2.2:8000` (emulator alias for the computer running the API)
/// 4. iOS simulator, desktop, and tests: `http://127.0.0.1:8000`
///
/// A physical Android device cannot use `10.0.2.2` or `localhost`. Pass the
/// computer's LAN address:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000`
class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static bool get hasOverride => _override.trim().isNotEmpty;

  static const String androidEmulatorHost = '10.0.2.2';
  static const int port = 8000;

  static String get baseUrl {
    if (hasOverride) {
      return _stripTrailingSlash(_override.trim());
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:$port';
    }
    final host = Platform.isAndroid ? androidEmulatorHost : '127.0.0.1';
    return 'http://$host:$port';
  }

  static String _stripTrailingSlash(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
