import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shipment.dart';
import '../models/tracking.dart';
import '../services/driver_location_service.dart';
import '../services/tracking_api.dart';
import 'api_providers.dart';
import 'logistics_providers.dart';

const trackableStatuses = {'PICKED_UP', 'IN_TRANSIT', 'ARRIVING'};

class TrackingSessionState {
  const TrackingSessionState({
    this.active = false,
    this.tracking = false,
    this.permission = 'unknown',
    this.message,
    this.lastSentAt,
    this.lastError,
    this.latitude,
    this.longitude,
  });

  final bool active;
  final bool tracking;
  final String permission;
  final String? message;
  final DateTime? lastSentAt;
  final String? lastError;
  final double? latitude;
  final double? longitude;

  TrackingSessionState copy({
    bool? active,
    bool? tracking,
    String? permission,
    String? message,
    DateTime? lastSentAt,
    String? lastError,
    double? latitude,
    double? longitude,
    bool clearError = false,
  }) {
    return TrackingSessionState(
      active: active ?? this.active,
      tracking: tracking ?? this.tracking,
      permission: permission ?? this.permission,
      message: message ?? this.message,
      lastSentAt: lastSentAt ?? this.lastSentAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class TrackingSession extends Notifier<TrackingSessionState> {
  DriverLocationService? _gps;
  var _paused = false;
  var _starting = false;

  @override
  TrackingSessionState build() {
    final gps = DriverLocationService(ref.watch(apiClientProvider));
    _gps = gps;
    ref.onDispose(gps.stop);
    return const TrackingSessionState();
  }

  Future<void> sync(List<Shipment> shipments) async {
    final trackable = shipments.any((item) => trackableStatuses.contains(item.status));
    if (!trackable) {
      _paused = false;
      _starting = false;
      await _gps?.stop();
      state = const TrackingSessionState(
        message: 'Tracking starts after you pick up a delivery.',
      );
      return;
    }
    if (_paused || state.tracking || _starting) {
      state = state.copy(active: true);
      return;
    }
    await _start();
  }

  Future<void> pause() async {
    _paused = true;
    _starting = false;
    await _gps?.stop();
    state = state.copy(active: true, tracking: false, message: 'Tracking paused.');
  }

  Future<void> resume() async {
    _paused = false;
    await _start();
  }

  Future<({double latitude, double longitude, double? accuracy})?> captureFix() async {
    final position = await _gps?.capture();
    if (position == null) {
      return null;
    }
    return (latitude: position.latitude, longitude: position.longitude, accuracy: position.accuracy);
  }

  Future<void> openSettings() {
    final permission = state.permission;
    if (permission == 'disabled') {
      return _gps?.openLocationSettings() ?? Future<void>.value();
    }
    return _gps?.openPermissionSettings() ?? Future<void>.value();
  }

  Future<void> _start() async {
    final gps = _gps;
    if (gps == null || _paused) {
      return;
    }
    _starting = true;
    state = state.copy(active: true, clearError: true, message: 'Starting location sharing.');
    await gps.start((reading) {
      if (!ref.mounted) {
        return;
      }
      state = state.copy(
        active: true,
        tracking: reading.tracking,
        permission: reading.permission,
        message: reading.message,
        lastSentAt: reading.lastSentAt,
        lastError: reading.lastError,
        latitude: reading.latitude,
        longitude: reading.longitude,
        clearError: reading.lastError == null,
      );
    });
    _starting = false;
  }
}

final trackingSessionProvider = NotifierProvider<TrackingSession, TrackingSessionState>(
  TrackingSession.new,
);

final trackingBinderProvider = Provider<void>((ref) {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  ref.listen(shipmentListProvider, (previous, next) {
    final items = next.value;
    if (items != null) {
      ref.read(trackingSessionProvider.notifier).sync(items);
    }
  });
  Future<void>.microtask(() {
    if (disposed) {
      return;
    }
    final items = ref.read(shipmentListProvider).value;
    if (items != null) {
      ref.read(trackingSessionProvider.notifier).sync(items);
    }
  });
});

final fleetLocationsProvider = StreamProvider<List<FleetDriver>>((ref) {
  final controller = StreamController<List<FleetDriver>>();
  final api = ref.watch(trackingApiProvider);
  Timer? timer;

  Future<void> tick() async {
    try {
      final fleet = await api.fleet();
      if (!controller.isClosed) {
        controller.add(fleet);
      }
    } catch (error, stack) {
      if (!controller.isClosed) {
        controller.addError(error, stack);
      }
    }
  }

  tick();
  timer = Timer.periodic(const Duration(seconds: 8), (_) => tick());
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

final shipmentTrackingProvider = StreamProvider.family<ShipmentTracking, String>((ref, shipmentId) {
  final controller = StreamController<ShipmentTracking>();
  final api = ref.watch(trackingApiProvider);
  Timer? timer;

  Future<void> tick() async {
    try {
      final tracking = await api.shipmentTracking(shipmentId);
      if (!controller.isClosed) {
        controller.add(tracking);
      }
    } catch (error, stack) {
      if (!controller.isClosed) {
        controller.addError(error, stack);
      }
    }
  }

  tick();
  timer = Timer.periodic(const Duration(seconds: 8), (_) => tick());
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});
