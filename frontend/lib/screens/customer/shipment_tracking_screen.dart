import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/maps_link.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/tracking_providers.dart';
import '../../widgets/fleet_scaffold.dart';
import '../../widgets/freshness_badge.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/tracking_map.dart';

class ShipmentTrackingScreen extends ConsumerWidget {
  const ShipmentTrackingScreen({super.key, required this.shipmentId});

  final String shipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(shipmentTrackingProvider(shipmentId));
    return FleetScaffold(
      title: 'Track driver',
      body: tracking.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorPane(
          message: error.toString(),
          onRetry: () => ref.invalidate(shipmentTrackingProvider(shipmentId)),
        ),
        data: (item) {
          final pins = <MapPin>[
            if (item.hasFix)
              MapPin(
                id: item.driverId ?? 'driver',
                latitude: item.latitude!,
                longitude: item.longitude!,
                title: item.driverName ?? 'Driver',
                snippet: item.vehicleNumber,
              ),
            if (item.destinationLatitude != null && item.destinationLongitude != null)
              MapPin(
                id: 'destination',
                latitude: item.destinationLatitude!,
                longitude: item.destinationLongitude!,
                title: 'Delivery',
                snippet: item.deliveryAddress,
                destination: true,
              ),
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.trackingNumber,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                            ),
                            StatusBadge(value: item.status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('Driver: ${item.driverName ?? 'Not assigned'}'),
                        Text('Vehicle: ${item.vehicleNumber ?? 'Not assigned'}'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FreshnessBadge(value: item.freshness),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.lastUpdated == null
                                    ? 'Last updated: unavailable'
                                    : 'Last updated: ${formatAgo(item.lastUpdated!)}',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (item.eta != null)
                          Text(
                            'Estimated arrival: ${formatClock(item.eta!)}'
                            '${item.distanceMeters == null ? '' : ' · ${formatDistance(item.distanceMeters!)}'}',
                          )
                        else
                          Text(item.message ?? 'Driver location is currently unavailable.'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final opened = await openDrivingDirections(
                              latitude: item.destinationLatitude,
                              longitude: item.destinationLongitude,
                              address: item.deliveryAddress,
                            );
                            if (!opened && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not open maps for this destination.')),
                              );
                            }
                          },
                          icon: const Icon(Icons.navigation_outlined),
                          label: const Text('Navigate'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: AppColors.card,
                      child: TrackingMap(
                        pins: pins,
                        route: [
                          for (final point in item.routePoints)
                            MapPin(
                              id: '${point.latitude},${point.longitude}',
                              latitude: point.latitude,
                              longitude: point.longitude,
                              title: '',
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
