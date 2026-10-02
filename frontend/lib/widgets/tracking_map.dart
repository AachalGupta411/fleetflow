import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/app_theme.dart';

class MapPin {
  const MapPin({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.title,
    this.snippet,
    this.destination = false,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String title;
  final String? snippet;
  final bool destination;

  LatLng get point => LatLng(latitude, longitude);
}

class TrackingMap extends StatefulWidget {
  const TrackingMap({
    super.key,
    required this.pins,
    this.route = const [],
    this.onPinTap,
  });

  final List<MapPin> pins;
  final List<MapPin> route;
  final ValueChanged<String>? onPinTap;

  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap> {
  final _controller = MapController();
  Timer? _demoTimer;
  List<LatLng> _demoPath = const [];
  var _demoStep = 0;
  var _demoPlaying = false;

  @override
  void dispose() {
    _demoTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _frame());
  }

  @override
  Widget build(BuildContext context) {
    final points = [...widget.pins, ...widget.route];
    final center = points.isEmpty ? const LatLng(19.07, 72.88) : points.first.point;
    final demoPoint = _demoPlaying && _demoPath.isNotEmpty ? _demoPath[_demoStep.clamp(0, _demoPath.length - 1)] : null;
    return Stack(
      children: [
        FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: points.isEmpty ? 9 : 12,
        onMapReady: _frame,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'dev.fleetflow.app',
        ),
        if (_demoPlaying && widget.route.length < 2 && _demoPath.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(points: _demoPath, color: Colors.black, strokeWidth: 4),
            ],
          ),
        if (widget.route.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [for (final point in widget.route) point.point],
                color: AppColors.blue,
                strokeWidth: 4,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (demoPoint != null)
              Marker(
                point: demoPoint,
                width: 36,
                height: 36,
                child: const Icon(Icons.local_shipping, color: Colors.black, size: 32),
              ),
            for (final pin in widget.pins)
              if (demoPoint == null || pin.destination)
              Marker(
                point: pin.point,
                width: 36,
                height: 36,
                child: GestureDetector(
                  onTap: pin.destination ? null : () => widget.onPinTap?.call(pin.id),
                  child: Icon(
                    Icons.location_on,
                    color: pin.destination ? const Color(0xFF38BDF8) : const Color(0xFFEF4444),
                    size: 36,
                  ),
                ),
              ),
          ],
        ),
        if (widget.pins.isEmpty && demoPoint == null)
          const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: _Caption('Driver location is currently unavailable.'),
            ),
          ),
        ],
      ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: _toggleDemo,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(_demoPlaying ? Icons.stop : Icons.play_arrow),
                label: Text(_demoPlaying ? 'Stop demo' : 'Play demo'),
              ),
              const SizedBox(width: 8),
              if (_demoPlaying)
                const Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.all(Radius.circular(8))),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(
                        'Demo playback. This is not a live GPS position.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleDemo() {
    if (_demoPlaying) {
      _demoTimer?.cancel();
      setState(() {
        _demoPlaying = false;
        _demoStep = 0;
      });
      _frame();
      return;
    }
    final path = _demoRoute();
    setState(() {
      _demoPath = path;
      _demoStep = 0;
      _demoPlaying = true;
    });
    _demoTimer?.cancel();
    _demoTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted) {
        return;
      }
      if (_demoStep >= _demoPath.length - 1) {
        _demoTimer?.cancel();
        return;
      }
      setState(() => _demoStep += 1);
      _controller.move(_demoPath[_demoStep], 13);
    });
  }

  List<LatLng> _demoRoute() {
    if (widget.route.length > 1) {
      final points = [for (final point in widget.route) point.point];
      if (points.length <= 10) {
        return points;
      }
      return [
        for (var step = 0; step <= 8; step++) points[(step * (points.length - 1) / 8).round()],
      ];
    }
    MapPin? destination;
    MapPin? driver;
    for (final pin in widget.pins) {
      if (pin.destination) {
        destination = pin;
      } else {
        driver = pin;
      }
    }
    final end = destination?.point ?? const LatLng(19.05, 73.02);
    final start = driver?.point ?? LatLng(end.latitude - 0.06, end.longitude - 0.08);
    return [
      for (var step = 0; step <= 8; step++)
        LatLng(
          start.latitude + (end.latitude - start.latitude) * step / 8,
          start.longitude + (end.longitude - start.longitude) * step / 8,
        ),
    ];
  }

  void _frame() {
    final points = [...widget.pins, ...widget.route];
    if (points.isEmpty) {
      return;
    }
    if (points.length == 1) {
      _controller.move(points.first.point, 13);
      return;
    }
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: [for (final point in points) point.point],
        padding: const EdgeInsets.all(48),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE6141822),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }
}

class MapsRequiredNotice extends StatelessWidget {
  const MapsRequiredNotice({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message ?? 'Driver location is currently unavailable.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, height: 1.4),
        ),
      ),
    );
  }
}
