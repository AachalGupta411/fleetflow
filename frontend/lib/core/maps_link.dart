import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

Uri? drivingDirectionsUri({double? latitude, double? longitude, required String address}) {
  if (latitude != null && longitude != null) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
      'travelmode': 'driving',
    });
  }
  final trimmed = address.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': trimmed,
    'travelmode': 'driving',
  });
}

Future<bool> openDrivingDirections({
  double? latitude,
  double? longitude,
  required String address,
}) async {
  final uri = drivingDirectionsUri(latitude: latitude, longitude: longitude, address: address);
  if (uri == null) {
    return false;
  }
  final mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
  return launchUrl(uri, mode: mode);
}
