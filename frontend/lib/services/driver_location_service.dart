import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';

class GpsReading {
  const GpsReading({
    required this.tracking,
    required this.permission,
    this.message,
    this.lastSentAt,
    this.lastError,
    this.latitude,
    this.longitude,
  });

  final bool tracking;
  final String permission;
  final String? message;
  final DateTime? lastSentAt;
  final String? lastError;
  final double? latitude;
  final double? longitude;
}

/// Foreground GPS sharing. Widgets talk to the tracking session, not this class.
class DriverLocationService {
  DriverLocationService(this._api);

  final ApiClient _api;
  StreamSubscription<Position>? _subscription;
  Timer? _heartbeat;
  DateTime? _lastSent;
  var _stopped = true;

  static const minGap = Duration(seconds: 12);
  static const heartbeatEvery = Duration(seconds: 15);

  Future<void> start(void Function(GpsReading) onUpdate) async {
    await stop();
    _stopped = false;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (_stopped) {
        return;
      }
      if (!enabled) {
        _stopped = true;
        onUpdate(
          const GpsReading(
            tracking: false,
            permission: 'disabled',
            message: 'Turn on location services to share your position.',
          ),
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (_stopped) {
        return;
      }
      if (permission == LocationPermission.denied) {
        _stopped = true;
        onUpdate(
          const GpsReading(
            tracking: false,
            permission: 'denied',
            message: 'Location permission is needed to share your position with FleetFlow.',
          ),
        );
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _stopped = true;
        onUpdate(
          const GpsReading(
            tracking: false,
            permission: 'deniedForever',
            message: 'Location permission is blocked. Enable it in Android settings.',
          ),
        );
        return;
      }
      onUpdate(
        const GpsReading(
          tracking: true,
          permission: 'granted',
          message: 'Waiting for a GPS fix.',
        ),
      );
      _subscription = Geolocator.getPositionStream(locationSettings: _settings()).listen(
        (position) {
          _publish(position, onUpdate);
        },
        onError: (Object error) {
          if (_stopped) {
            return;
          }
          onUpdate(
            GpsReading(
              tracking: true,
              permission: 'granted',
              message: 'GPS update failed. FleetFlow will try again.',
              lastError: error.toString(),
            ),
          );
        },
      );
      _heartbeat = Timer.periodic(heartbeatEvery, (_) {
        _readCurrent(onUpdate);
      });
      await _readCurrent(onUpdate, force: true);
    } catch (error) {
      _stopped = true;
      await _subscription?.cancel();
      _subscription = null;
      _heartbeat?.cancel();
      onUpdate(
        GpsReading(
          tracking: false,
          permission: 'unavailable',
          message: 'Location is unavailable on this device.',
          lastError: error.toString(),
        ),
      );
    }
  }

  Future<void> stop() async {
    _stopped = true;
    _heartbeat?.cancel();
    _heartbeat = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<Position?> capture() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(locationSettings: _settings());
    } catch (_) {
      return null;
    }
  }

  Future<void> openPermissionSettings() {
    return Geolocator.openAppSettings();
  }

  Future<void> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        intervalDuration: heartbeatEvery,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    );
  }

  Future<void> _readCurrent(void Function(GpsReading) onUpdate, {bool force = false}) async {
    if (_stopped) {
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition(locationSettings: _settings());
      await _publish(position, onUpdate, force: force);
    } catch (error) {
      if (_stopped) {
        return;
      }
      onUpdate(
        GpsReading(
          tracking: true,
          permission: 'granted',
          message: 'Could not read the current GPS position.',
          lastError: error.toString(),
        ),
      );
    }
  }

  Future<void> _publish(
    Position position,
    void Function(GpsReading) onUpdate, {
    bool force = false,
  }) async {
    if (_stopped) {
      return;
    }
    final now = DateTime.now();
    if (!force && _lastSent != null && now.difference(_lastSent!) < minGap) {
      return;
    }
    _lastSent = now;
    try {
      await _api.send(
        'POST',
        '/api/v1/tracking/location',
        body: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          if (position.accuracy >= 0) 'accuracy': position.accuracy,
          if (position.speed >= 0) 'speed': position.speed,
          if (position.heading >= 0 && position.heading <= 360) 'heading': position.heading,
        },
      );
      if (_stopped) {
        return;
      }
      onUpdate(
        GpsReading(
          tracking: true,
          permission: 'granted',
          message: 'Location shared. The fleet map picks this up within a few seconds.',
          lastSentAt: now,
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } on ApiException catch (error) {
      if (_stopped) {
        return;
      }
      onUpdate(
        GpsReading(
          tracking: true,
          permission: 'granted',
          message: 'The last location update failed. FleetFlow will try again.',
          lastError: error.message,
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } catch (_) {
      if (_stopped) {
        return;
      }
      onUpdate(
        GpsReading(
          tracking: true,
          permission: 'granted',
          message: 'The last location update failed. FleetFlow will try again.',
          lastError: 'The last location update failed. FleetFlow will try again.',
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    }
  }
}
