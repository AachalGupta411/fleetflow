import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/router/app_routes.dart';
import '../../models/driver_profile.dart';
import '../../models/shipment.dart';
import '../../models/tracking.dart';
import '../../models/vehicle.dart';
import '../../providers/auth_provider.dart';
import '../../providers/logistics_providers.dart';
import '../../providers/tracking_providers.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/tracking_map.dart';

class ManagerHomeScreen extends ConsumerStatefulWidget {
  const ManagerHomeScreen({super.key, this.admin = false});

  final bool admin;

  @override
  ConsumerState<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends ConsumerState<ManagerHomeScreen> {
  final _search = TextEditingController();
  String? _selectedId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shipments = ref.watch(shipmentListProvider);
    final drivers = ref.watch(driverListProvider);
    final vehicles = ref.watch(vehicleListProvider);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1180;
    final phone = width < 800;

    return Scaffold(
      backgroundColor: _Dash.bg,
      drawer: phone ? Drawer(backgroundColor: _Dash.panel, child: _ManagerDrawer(admin: widget.admin)) : null,
      body: shipments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Retry(
          message: error.toString(),
          onRetry: () {
            ref.invalidate(shipmentListProvider);
            ref.invalidate(driverListProvider);
            ref.invalidate(vehicleListProvider);
          },
        ),
        data: (shipmentItems) {
          final driverItems = drivers.asData?.value ?? const <DriverProfile>[];
          final vehicleItems = vehicles.asData?.value ?? const <VehicleRecord>[];
          final visible = _visible(shipmentItems);
          final selected = _selected(shipmentItems);
          final user = ref.watch(authProvider).user;
          return SafeArea(
            child: Row(
              children: [
                if (!phone) _Rail(admin: widget.admin, initials: _initials(user?.name ?? 'F')),
                Expanded(
                  child: wide
                      ? Row(
                          children: [
                            Expanded(
                              child: _Workspace(
                                shipment: selected,
                                drivers: driverItems,
                                vehicles: vehicleItems,
                                admin: widget.admin,
                                compact: phone,
                              ),
                            ),
                            SizedBox(
                              width: 340,
                              child: _ShipmentList(
                                items: visible,
                                selectedId: selected?.id,
                                controller: _search,
                                onQuery: (_) => setState(() {}),
                                onSelect: (id) => setState(() => _selectedId = id),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            SizedBox(
                              height: 220,
                              child: _ShipmentList(
                                items: visible,
                                selectedId: selected?.id,
                                controller: _search,
                                onQuery: (_) => setState(() {}),
                                onSelect: (id) => setState(() => _selectedId = id),
                              ),
                            ),
                            Expanded(
                              child: _Workspace(
                                shipment: selected,
                                drivers: driverItems,
                                vehicles: vehicleItems,
                                admin: widget.admin,
                                compact: phone,
                              ),
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

  List<Shipment> _visible(List<Shipment> items) {
    final query = _search.text.trim().toLowerCase();
    final matched = items.where((item) {
      if (query.isEmpty) {
        return true;
      }
      return item.trackingNumber.toLowerCase().contains(query) ||
          (item.driverName ?? '').toLowerCase().contains(query) ||
          (item.vehicleNumber ?? '').toLowerCase().contains(query) ||
          item.customerName.toLowerCase().contains(query);
    }).toList();
    matched.sort((a, b) {
      if (a.isActive == b.isActive) {
        return a.trackingNumber.compareTo(b.trackingNumber);
      }
      return a.isActive ? -1 : 1;
    });
    return matched;
  }

  Shipment? _selected(List<Shipment> items) {
    for (final item in items) {
      if (item.id == _selectedId) {
        return item;
      }
    }
    for (final item in items) {
      if (item.isActive) {
        return item;
      }
    }
    return items.isEmpty ? null : items.first;
  }
}

class _Dash {
  static const bg = Color(0xFF10141C);
  static const panel = Color(0xFF171C26);
  static const card = Color(0xFF1E2531);
  static const blue = Color(0xFF2563EB);
  static const text = Color(0xFFF5F7FB);
  static const muted = Color(0xFF9AA6B8);
  static const line = Color(0xFF2C3544);
}

class _Rail extends StatelessWidget {
  const _Rail({required this.admin, required this.initials});

  final bool admin;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      color: _Dash.panel,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Icon(Icons.local_shipping_outlined, color: _Dash.blue, size: 26),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
          _RailIcon(icon: Icons.dashboard_outlined, tooltip: 'Dashboard', selected: true, onTap: () {}),
          _RailIcon(
            icon: Icons.near_me_outlined,
            tooltip: 'Tracking',
            onTap: () => context.go(admin ? AppRoutes.adminFleet : AppRoutes.managerFleet),
          ),
          _RailIcon(
            icon: Icons.inventory_2_outlined,
            tooltip: 'Shipments',
            onTap: () => context.go(admin ? AppRoutes.adminShipments : AppRoutes.managerShipments),
          ),
          _RailIcon(
            icon: Icons.badge_outlined,
            tooltip: 'Drivers',
            onTap: () => context.go(admin ? AppRoutes.adminDrivers : AppRoutes.managerDrivers),
          ),
          _RailIcon(
            icon: Icons.local_shipping_outlined,
            tooltip: 'Vehicles',
            onTap: () => context.go(admin ? AppRoutes.adminVehicles : AppRoutes.managerVehicles),
          ),
          _RailIcon(
            icon: Icons.insights_outlined,
            tooltip: 'Operations',
            onTap: () => context.go(admin ? AppRoutes.adminOperations : AppRoutes.managerOperations),
          ),
          _RailIcon(
            icon: Icons.currency_rupee,
            tooltip: 'Pricing',
            onTap: () => context.go(admin ? AppRoutes.adminPricing : AppRoutes.managerPricing),
          ),
          _RailIcon(
            icon: Icons.notifications_none,
            tooltip: 'Alerts',
            onTap: () => context.go(admin ? AppRoutes.adminAlerts : AppRoutes.managerAlerts),
          ),
          if (admin)
            _RailIcon(
              icon: Icons.group_outlined,
              tooltip: 'Users',
              onTap: () => context.go(AppRoutes.adminUsers),
            ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: _Dash.blue,
            child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          _RailIcon(
            icon: Icons.logout,
            tooltip: 'Sign out',
            onTap: () => ProviderScope.containerOf(context).read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({required this.icon, required this.tooltip, required this.onTap, this.selected = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: selected ? _Dash.blue : Colors.transparent,
          foregroundColor: selected ? Colors.white : _Dash.muted,
          fixedSize: const Size(44, 44),
        ),
        icon: Icon(icon, size: 22),
      ),
    );
  }
}

class _ManagerDrawer extends StatelessWidget {
  const _ManagerDrawer({required this.admin});

  final bool admin;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          const ListTile(
            title: Text('FleetFlow', style: TextStyle(color: _Dash.text, fontWeight: FontWeight.w800)),
          ),
          _DrawerLink(icon: Icons.near_me_outlined, label: 'Tracking', onTap: () => context.go(admin ? AppRoutes.adminFleet : AppRoutes.managerFleet)),
          _DrawerLink(icon: Icons.inventory_2_outlined, label: 'Shipments', onTap: () => context.go(admin ? AppRoutes.adminShipments : AppRoutes.managerShipments)),
          _DrawerLink(icon: Icons.badge_outlined, label: 'Drivers', onTap: () => context.go(admin ? AppRoutes.adminDrivers : AppRoutes.managerDrivers)),
          _DrawerLink(icon: Icons.local_shipping_outlined, label: 'Vehicles', onTap: () => context.go(admin ? AppRoutes.adminVehicles : AppRoutes.managerVehicles)),
          _DrawerLink(icon: Icons.insights_outlined, label: 'Operations', onTap: () => context.go(admin ? AppRoutes.adminOperations : AppRoutes.managerOperations)),
          _DrawerLink(icon: Icons.currency_rupee, label: 'Pricing', onTap: () => context.go(admin ? AppRoutes.adminPricing : AppRoutes.managerPricing)),
          _DrawerLink(icon: Icons.notifications_none, label: 'Alerts', onTap: () => context.go(admin ? AppRoutes.adminAlerts : AppRoutes.managerAlerts)),
          if (admin) _DrawerLink(icon: Icons.group_outlined, label: 'Users', onTap: () => context.go(AppRoutes.adminUsers)),
          _DrawerLink(
            icon: Icons.logout,
            label: 'Sign out',
            onTap: () => ProviderScope.containerOf(context).read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

class _DrawerLink extends StatelessWidget {
  const _DrawerLink({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _Dash.text),
      title: Text(label, style: const TextStyle(color: _Dash.text)),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace({
    required this.shipment,
    required this.drivers,
    required this.vehicles,
    required this.admin,
    required this.compact,
  });

  final Shipment? shipment;
  final List<DriverProfile> drivers;
  final List<VehicleRecord> vehicles;
  final bool admin;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final item = shipment;
    if (item == null) {
      return const Center(child: Text('No shipments yet.', style: TextStyle(color: _Dash.muted, fontSize: 16)));
    }
    DriverProfile? driver;
    for (final profile in drivers) {
      if (profile.id == item.assignedDriverId) {
        driver = profile;
        break;
      }
    }
    VehicleRecord? vehicle;
    for (final record in vehicles) {
      if (record.id == item.assignedVehicleId) {
        vehicle = record;
        break;
      }
    }
    final name = item.driverName ?? 'Unassigned';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (compact)
                IconButton(
                  tooltip: 'Menu',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu, color: _Dash.text),
                ),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _Dash.text, fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              if (!compact) Text(_today(), style: const TextStyle(color: _Dash.muted)),
              if (!compact) const SizedBox(width: 12),
              _StatusChip(value: item.status),
            ],
          ),
          if (compact)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_today(), style: const TextStyle(color: _Dash.muted)),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 760;
                final cards = [
                  _VehicleCard(shipment: item, vehicle: vehicle),
                  _InfoCard(shipment: item),
                  _DriverCard(shipment: item, driver: driver, admin: admin),
                ];
                final map = _MapPanel(shipment: item);
                final route = _RouteCard(shipment: item);
                if (stacked) {
                  return ListView(
                    children: [
                      for (final card in cards) ...[
                        SizedBox(height: 180, child: card),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(height: 240, child: map),
                      const SizedBox(height: 12),
                      SizedBox(height: 220, child: route),
                    ],
                  );
                }
                return Column(
                  children: [
                    SizedBox(
                      height: 196,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var index = 0; index < cards.length; index++) ...[
                            if (index > 0) const SizedBox(width: 12),
                            Expanded(child: cards[index]),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: map),
                          const SizedBox(width: 12),
                          Expanded(child: route),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.shipment, required this.vehicle});

  final Shipment shipment;
  final VehicleRecord? vehicle;

  @override
  Widget build(BuildContext context) {
    final number = vehicle?.vehicleNumber ?? shipment.vehicleNumber ?? 'No vehicle';
    final detail = vehicle == null ? 'Not assigned' : '${vehicle!.model} · ${prettyLabel(vehicle!.vehicleType)}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _Dash.blue, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_shipping, color: Colors.white, size: 42),
          const Spacer(),
          Text(number, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(color: Color(0xFFD6E4FF))),
          if (vehicle != null) ...[
            const SizedBox(height: 8),
            Text('Capacity ${vehicle!.capacity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.shipment});

  final Shipment shipment;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Shipment',
      child: Column(
        children: [
          _Fact('Tracking', shipment.trackingNumber),
          _Fact('Customer', shipment.customerName),
          _Fact('Priority', prettyLabel(shipment.priority)),
          _Fact('Package', shipment.packageDescription),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.shipment, required this.driver, required this.admin});

  final Shipment shipment;
  final DriverProfile? driver;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    final name = driver?.name ?? shipment.driverName ?? 'Unassigned';
    return _Panel(
      title: 'Driver',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF243044),
                child: Text(_initials(name), style: const TextStyle(color: _Dash.text, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: _Dash.text, fontWeight: FontWeight.w700)),
                    Text(driver?.email ?? 'No driver email', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _Dash.muted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: () => context.push(admin ? AppRoutes.adminShipment(shipment.id) : AppRoutes.managerShipment(shipment.id)),
            style: TextButton.styleFrom(
              backgroundColor: _Dash.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Open shipment'),
          ),
        ],
      ),
    );
  }
}

class _MapPanel extends StatelessWidget {
  const _MapPanel({required this.shipment});

  final Shipment shipment;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(color: _Dash.card, child: _LiveMap(shipmentId: shipment.id, title: shipment.trackingNumber)),
    );
  }
}

class _LiveMap extends ConsumerWidget {
  const _LiveMap({required this.shipmentId, required this.title});

  final String shipmentId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(shipmentTrackingProvider(shipmentId));
    return tracking.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString(), style: const TextStyle(color: _Dash.muted))),
      data: (item) {
        final pins = <MapPin>[
          if (item.latitude != null && item.longitude != null)
            MapPin(id: 'driver', latitude: item.latitude!, longitude: item.longitude!, title: item.driverName ?? title),
          if (item.destinationLatitude != null && item.destinationLongitude != null)
            MapPin(
              id: 'drop',
              latitude: item.destinationLatitude!,
              longitude: item.destinationLongitude!,
              title: 'Delivery',
              destination: true,
            ),
        ];
        if (pins.isEmpty && item.routePoints.isNotEmpty) {
          final point = item.routePoints.first;
          pins.add(MapPin(id: 'route', latitude: point.latitude, longitude: point.longitude, title: title));
        }
        return Stack(
          children: [
            TrackingMap(
              pins: pins,
              route: [
                for (final point in item.routePoints)
                  MapPin(id: '${point.latitude},${point.longitude}', latitude: point.latitude, longitude: point.longitude, title: ''),
              ],
            ),
            Positioned(left: 12, top: 12, right: 12, child: _MapFacts(item: item)),
          ],
        );
      },
    );
  }
}

class _MapFacts extends StatelessWidget {
  const _MapFacts({required this.item});

  final ShipmentTracking item;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (item.durationSeconds != null) _MapChip(Icons.schedule, _duration(item.durationSeconds!)),
      if (item.distanceMeters != null) _MapChip(Icons.route, formatDistance(item.distanceMeters!)),
      _MapChip(Icons.sensors, prettyLabel(item.freshness)),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xF0141822), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RouteCard extends ConsumerWidget {
  const _RouteCard({required this.shipment});

  final Shipment shipment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(shipmentTrackingProvider(shipment.id));
    final eta = tracking.asData?.value.eta;
    return _Panel(
      title: 'Route',
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Stop(label: 'Pickup', value: shipment.pickupAddress),
          _Stop(label: 'Delivery', value: shipment.deliveryAddress),
          if (tracking.isLoading && eta == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Checking the route…', style: TextStyle(color: _Dash.muted)),
            )
          else if (eta != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Estimated arrival ${formatClock(eta)}${tracking.asData?.value.distanceMeters == null ? '' : ' · ${formatDistance(tracking.asData!.value.distanceMeters!)}'}',
                style: const TextStyle(color: _Dash.text),
              ),
            )
          else if (tracking.asData?.value.message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(tracking.asData!.value.message!, style: const TextStyle(color: _Dash.muted)),
            ),
        ],
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 8, color: _Dash.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: _Dash.muted, fontSize: 12)),
                Text(value, style: const TextStyle(color: _Dash.text, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShipmentList extends StatelessWidget {
  const _ShipmentList({
    required this.items,
    required this.selectedId,
    required this.controller,
    required this.onQuery,
    required this.onSelect,
  });

  final List<Shipment> items;
  final String? selectedId;
  final TextEditingController controller;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _Dash.panel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Shipments', style: TextStyle(color: _Dash.text, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              onChanged: onQuery,
              style: const TextStyle(color: _Dash.text),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: const TextStyle(color: _Dash.muted),
                prefixIcon: const Icon(Icons.search, color: _Dash.muted, size: 20),
                filled: true,
                fillColor: _Dash.card,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('No matching shipments.', style: TextStyle(color: _Dash.muted)))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selected = item.id == selectedId;
                        return Material(
                          color: selected ? const Color(0xFF243044) : _Dash.card,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => onSelect(item.id),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFF2A3344),
                                    child: Text(
                                      _initials(item.driverName ?? item.customerName),
                                      style: const TextStyle(color: _Dash.text, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.driverName ?? 'Unassigned',
                                          style: const TextStyle(color: _Dash.text, fontWeight: FontWeight.w700),
                                        ),
                                        Text(item.trackingNumber, style: const TextStyle(color: _Dash.muted, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  _StatusChip(value: item.status),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Dash.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Dash.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(color: _Dash.muted, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: const TextStyle(color: _Dash.muted, fontSize: 12))),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _Dash.text, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (value) {
      'DELIVERED' || 'AVAILABLE' => (const Color(0xFF14532D), const Color(0xFF86EFAC)),
      'FAILED' || 'CANCELLED' || 'INACTIVE' => (const Color(0xFF7F1D1D), const Color(0xFFFECACA)),
      'PENDING' || 'MAINTENANCE' => (const Color(0xFF713F12), const Color(0xFFFDE68A)),
      _ => (const Color(0xFF1E3A8A), const Color(0xFFBFDBFE)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(prettyLabel(value), style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(color: _Dash.text)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}

String _today() {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final now = DateTime.now();
  return '${weekdays[now.weekday - 1]} ${now.day} ${months[now.month - 1]} ${now.year}';
}

String _duration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}m';
}
