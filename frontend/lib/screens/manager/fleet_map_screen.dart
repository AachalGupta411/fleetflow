import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/shipment.dart';
import '../../models/tracking.dart';
import '../../providers/auth_provider.dart';
import '../../providers/logistics_providers.dart';
import '../../providers/tracking_providers.dart';
import '../../widgets/freshness_badge.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/tracking_map.dart';

class FleetMapScreen extends ConsumerStatefulWidget {
  const FleetMapScreen({super.key});

  @override
  ConsumerState<FleetMapScreen> createState() => _FleetMapScreenState();
}

class _FleetMapScreenState extends ConsumerState<FleetMapScreen> {
  final _search = TextEditingController();
  String _filter = 'All';
  String? _selectedId;
  var _showDetail = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shipments = ref.watch(shipmentListProvider);
    final fleet = ref.watch(fleetLocationsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1080;
    return Scaffold(
      backgroundColor: _Board.bg,
      body: shipments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Message(
          message: error.toString(),
          onRetry: () => ref.invalidate(shipmentListProvider),
        ),
        data: (items) {
          final fixes = fleet.asData?.value ?? const <FleetDriver>[];
          final visible = _visible(items);
          final selected = _selected(visible);
          return SafeArea(
            child: Row(
            children: [
              if (wide) _Rail(admin: _admin(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      controller: _search,
                      onQuery: (_) => setState(() {}),
                      onSignOut: () => ref.read(authProvider.notifier).logout(),
                    ),
                    _Filters(
                      filter: _filter,
                      counts: _counts(items),
                      onSelected: (value) => setState(() => _filter = value),
                    ),
                    Expanded(
                      child: wide
                          ? Row(
                              children: [
                                Expanded(child: _Grid(items: visible, selectedId: selected?.id, onSelect: _select)),
                                SizedBox(width: 420, child: _Detail(shipment: selected, fixes: fixes)),
                              ],
                            )
                          : _showDetail && selected != null
                              ? Column(
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () => setState(() => _showDetail = false),
                                        icon: const Icon(Icons.arrow_back, color: _Board.text),
                                        label: const Text('Shipments', style: TextStyle(color: _Board.text)),
                                      ),
                                    ),
                                    Expanded(child: _Detail(shipment: selected, fixes: fixes)),
                                  ],
                                )
                              : _Grid(items: visible, selectedId: selected?.id, onSelect: _select),
                    ),
                  ],
                ),
              ),
            ],
            ),
          );
        },
      ),
    );
  }

  void _select(String id) => setState(() {
        _selectedId = id;
        _showDetail = true;
      });

  List<Shipment> _visible(List<Shipment> items) {
    final query = _search.text.trim().toLowerCase();
    return items.where((item) {
      final active = item.isActive;
      final matchesFilter = _filter == 'All' || (_filter == 'Active' && active) || (_filter == 'Inactive' && !active);
      final matchesQuery = query.isEmpty ||
          item.trackingNumber.toLowerCase().contains(query) ||
          (item.driverName ?? '').toLowerCase().contains(query) ||
          (item.vehicleNumber ?? '').toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  Shipment? _selected(List<Shipment> items) {
    for (final item in items) {
      if (item.id == _selectedId) {
        return item;
      }
    }
    return items.isEmpty ? null : items.first;
  }

  Map<String, int> _counts(List<Shipment> items) {
    return {
      'All': items.length,
      'Active': items.where((item) => item.isActive).length,
      'Inactive': items.where((item) => !item.isActive).length,
    };
  }

  bool _admin(BuildContext context) => GoRouterState.of(context).uri.path.startsWith('/admin');
}

class _Board {
  static const bg = Color(0xFF0F1115);
  static const panel = Color(0xFF171A21);
  static const card = Color(0xFF1C212B);
  static const line = Color(0xFF2C3442);
  static const accent = Color(0xFF3B82F6);
  static const text = Color(0xFFF4F7FB);
  static const muted = Color(0xFF9AA6B8);
}

class _Rail extends StatelessWidget {
  const _Rail({required this.admin});

  final bool admin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: _Board.panel,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 24),
            child: Text('FleetFlow', style: TextStyle(color: _Board.text, fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          _RailButton(label: 'Dashboard', icon: Icons.dashboard_outlined, onTap: () => context.go(admin ? AppRoutes.admin : AppRoutes.manager)),
          _RailButton(label: 'Tracking', icon: Icons.near_me_outlined, selected: true, onTap: () => context.go(admin ? AppRoutes.adminFleet : AppRoutes.managerFleet)),
          _RailButton(label: 'Shipments', icon: Icons.inventory_2_outlined, onTap: () => context.go(admin ? AppRoutes.adminShipments : AppRoutes.managerShipments)),
          _RailButton(label: 'Drivers', icon: Icons.badge_outlined, onTap: () => context.go(admin ? AppRoutes.adminDrivers : AppRoutes.managerDrivers)),
          _RailButton(label: 'Vehicles', icon: Icons.local_shipping_outlined, onTap: () => context.go(admin ? AppRoutes.adminVehicles : AppRoutes.managerVehicles)),
          _RailButton(label: 'Analysis', icon: Icons.insights_outlined, onTap: () => context.go(admin ? AppRoutes.adminAnalytics : AppRoutes.managerAnalytics)),
          const Spacer(),
          _RailButton(label: 'Alerts', icon: Icons.notifications_none, onTap: () => context.go(admin ? AppRoutes.adminAlerts : AppRoutes.managerAlerts)),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.label, required this.icon, required this.onTap, this.selected = false});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: selected ? Colors.white : _Board.muted),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, style: TextStyle(color: selected ? Colors.white : _Board.muted, fontWeight: FontWeight.w600)),
        ),
        style: TextButton.styleFrom(
          backgroundColor: selected ? _Board.accent : Colors.transparent,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onQuery, required this.onSignOut});

  final TextEditingController controller;
  final ValueChanged<String> onQuery;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 1080;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
      child: narrow
          ? Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back, color: _Board.text),
                    ),
                    const Expanded(
                      child: Text('Tracking', style: TextStyle(color: _Board.text, fontSize: 22, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      tooltip: 'Sign out',
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout, color: _Board.muted),
                    ),
                  ],
                ),
                TextField(
                  controller: controller,
                  onChanged: onQuery,
                  style: const TextStyle(color: _Board.text),
                  decoration: _searchDecoration(),
                ),
              ],
            )
          : Row(
        children: [
          const Text('Tracking', style: TextStyle(color: _Board.text, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(width: 20),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onQuery,
              style: const TextStyle(color: _Board.text),
              decoration: _searchDecoration(),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout, color: _Board.muted),
          ),
        ],
      ),
    );
  }
}

InputDecoration _searchDecoration() {
  return InputDecoration(
    hintText: 'Search tracking number, driver, or vehicle',
    hintStyle: const TextStyle(color: _Board.muted),
    prefixIcon: const Icon(Icons.search, color: _Board.muted),
    filled: true,
    fillColor: _Board.card,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    isDense: true,
  );
}

class _Filters extends StatelessWidget {
  const _Filters({required this.filter, required this.counts, required this.onSelected});

  final String filter;
  final Map<String, int> counts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final label in const ['All', 'Active', 'Inactive'])
            ChoiceChip(
                label: Text('$label ${counts[label]}'),
                selected: filter == label,
                onSelected: (_) => onSelected(label),
                selectedColor: _Board.accent,
                labelStyle: TextStyle(color: filter == label ? Colors.white : _Board.muted),
                backgroundColor: _Board.card,
                side: const BorderSide(color: _Board.line),
              ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items, required this.selectedId, required this.onSelect});

  final List<Shipment> items;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No shipments in this filter.', style: TextStyle(color: _Board.muted)));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisExtent: 168,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = item.id == selectedId;
        return Material(
          color: _Board.card,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelect(item.id),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: selected ? _Board.accent : _Board.line, width: selected ? 2 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.trackingNumber, style: const TextStyle(color: _Board.text, fontWeight: FontWeight.w800)),
                      ),
                      StatusBadge(value: item.status),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.local_shipping_outlined, color: _Board.muted, size: 36),
                  const SizedBox(height: 10),
                  Text(item.vehicleNumber ?? 'No vehicle', style: const TextStyle(color: _Board.text)),
                  Text(item.driverName ?? 'Unassigned', style: const TextStyle(color: _Board.muted, fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.shipment, required this.fixes});

  final Shipment? shipment;
  final List<FleetDriver> fixes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = shipment;
    if (item == null) {
      return const ColoredBox(
        color: _Board.panel,
        child: Center(child: Text('Select a shipment.', style: TextStyle(color: _Board.muted))),
      );
    }
    FleetDriver? fix;
    for (final driver in fixes) {
      if (driver.shipmentId == item.id) {
        fix = driver;
        break;
      }
    }
    final admin = GoRouterState.of(context).uri.path.startsWith('/admin');
    return ColoredBox(
      color: _Board.panel,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.trackingNumber, style: const TextStyle(color: _Board.text, fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              StatusBadge(value: item.status),
            ],
          ),
          const SizedBox(height: 16),
          _Line('Driver', item.driverName ?? 'Unassigned'),
          _Line('Vehicle', item.vehicleNumber ?? 'Unassigned'),
          _Line('Pickup', item.pickupAddress),
          _Line('Delivery', item.deliveryAddress),
          if (item.failureReason != null) _Line('Failure', item.failureReason!),
          if (fix != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                FreshnessBadge(value: fix.freshness),
                const SizedBox(width: 8),
                Text(
                  fix.lastUpdated == null ? 'No location yet' : 'Updated ${formatAgo(fix.lastUpdated!)}',
                  style: const TextStyle(color: _Board.muted),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(height: 220, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: _Map(shipment: item, fix: fix))),
          _Eta(shipmentId: item.id),
          if (item.podAvailable) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.push(admin ? AppRoutes.adminProof(item.id) : AppRoutes.managerProof(item.id)),
              child: const Text('View proof of delivery'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Map extends ConsumerWidget {
  const _Map({required this.shipment, required this.fix});

  final Shipment shipment;
  final FleetDriver? fix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(shipmentTrackingProvider(shipment.id));
    final pins = <MapPin>[
      if (fix != null && fix!.hasFix)
        MapPin(id: fix!.driverId, latitude: fix!.latitude!, longitude: fix!.longitude!, title: fix!.driverName),
    ];
    final tracked = tracking.asData?.value;
    final route = tracked?.routePoints ?? const [];
    if (tracked?.destinationLatitude != null && tracked?.destinationLongitude != null) {
      pins.add(
        MapPin(
          id: 'drop',
          latitude: tracked!.destinationLatitude!,
          longitude: tracked.destinationLongitude!,
          title: 'Delivery',
          destination: true,
        ),
      );
    }
    return TrackingMap(
      pins: pins,
      route: [for (final point in route) MapPin(id: '${point.latitude},${point.longitude}', latitude: point.latitude, longitude: point.longitude, title: '')],
    );
  }
}

class _Eta extends ConsumerWidget {
  const _Eta({required this.shipmentId});

  final String shipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(shipmentTrackingProvider(shipmentId));
    return tracking.when(
      loading: () => const Padding(padding: EdgeInsets.only(top: 10), child: Text('Estimating arrival…', style: TextStyle(color: _Board.muted))),
      error: (error, _) => Padding(padding: const EdgeInsets.only(top: 10), child: Text(error.toString(), style: const TextStyle(color: AppColors.danger))),
      data: (item) {
        if (item.eta == null) {
          return Padding(padding: const EdgeInsets.only(top: 10), child: Text(item.message ?? 'ETA is unavailable.', style: const TextStyle(color: _Board.muted)));
        }
        final distance = item.distanceMeters == null ? '' : ' · ${formatDistance(item.distanceMeters!)}';
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('Estimated arrival ${formatClock(item.eta!)}$distance', style: const TextStyle(color: _Board.text)),
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _Board.muted, fontSize: 12)),
          Text(value, style: const TextStyle(color: _Board.text)),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(color: _Board.text)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
