import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/driver_profile.dart';
import '../../models/shipment.dart';
import '../../models/vehicle.dart';
import '../../providers/logistics_providers.dart';
import '../../services/logistics_service.dart';
import '../../widgets/status_badge.dart';

class ManagerShipmentScreen extends ConsumerStatefulWidget {
  const ManagerShipmentScreen({super.key, required this.shipmentId});

  final String shipmentId;

  @override
  ConsumerState<ManagerShipmentScreen> createState() => _ManagerShipmentScreenState();
}

class _ManagerShipmentScreenState extends ConsumerState<ManagerShipmentScreen> {
  String? _driverId;
  String? _vehicleId;
  String? _error;
  bool _submitting = false;

  Future<void> _assign() async {
    if (_driverId == null || _vehicleId == null) {
      setState(() => _error = 'Choose an available driver and vehicle.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(logisticsServiceProvider).assignShipment(
        shipmentId: widget.shipmentId,
        driverId: _driverId!,
        vehicleId: _vehicleId!,
      );
      ref.invalidate(shipmentProvider(widget.shipmentId));
      ref.invalidate(shipmentListProvider);
      ref.invalidate(driverListProvider);
      ref.invalidate(vehicleListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shipment assigned')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shipment = ref.watch(shipmentProvider(widget.shipmentId));
    final drivers = ref.watch(driverListProvider);
    final vehicles = ref.watch(vehicleListProvider);
    final shipments = ref.watch(shipmentListProvider);
    final admin = GoRouterState.of(context).uri.path.startsWith('/admin');
    return Scaffold(
      backgroundColor: _Ink.bg,
      appBar: AppBar(
        backgroundColor: _Ink.panel,
        foregroundColor: _Ink.text,
        title: const Text('Shipment'),
      ),
      body: shipment.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Message(message: error.toString(), onRetry: () => ref.invalidate(shipmentProvider(widget.shipmentId))),
        data: (item) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.trackingNumber,
                          style: const TextStyle(color: _Ink.text, fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                      ),
                      _StatusChip(value: item.status),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 680;
                      final route = _Card(
                        title: 'Route',
                        child: Column(
                          children: [
                            _Line(label: 'Pickup', value: item.pickupAddress),
                            _Line(label: 'Delivery', value: item.deliveryAddress),
                          ],
                        ),
                      );
                      final details = _Card(
                        title: 'Details',
                        child: Column(
                          children: [
                            _Line(label: 'Customer', value: item.customerName),
                            _Line(label: 'Priority', value: prettyLabel(item.priority)),
                            _Line(label: 'Package', value: item.packageDescription),
                            _Line(label: 'Driver', value: item.driverName ?? 'Unassigned'),
                            _Line(label: 'Vehicle', value: item.vehicleNumber ?? 'Unassigned'),
                            if (item.failureReason != null) _Line(label: 'Failure', value: item.failureReason!),
                            if (item.failureNotes != null) _Line(label: 'Notes', value: item.failureNotes!),
                          ],
                        ),
                      );
                      if (stacked) {
                        return Column(children: [route, const SizedBox(height: 12), details]);
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: route),
                          const SizedBox(width: 12),
                          Expanded(child: details),
                        ],
                      );
                    },
                  ),
                  if (item.podAvailable) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.push(admin ? AppRoutes.adminProof(item.id) : AppRoutes.managerProof(item.id)),
                      style: FilledButton.styleFrom(backgroundColor: _Ink.blue, foregroundColor: Colors.white),
                      child: const Text('View proof of delivery'),
                    ),
                  ],
                  if (item.status == 'PENDING') ...[
                    const SizedBox(height: 16),
                    _Card(
                      title: 'Assign driver and vehicle',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          drivers.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (error, _) => Text(error.toString(), style: const TextStyle(color: AppColors.danger)),
                            data: (items) => _driverMenu(
                              items.where((driver) => driver.status == 'AVAILABLE' && driver.isActive).toList(),
                              busy: items.where((driver) => driver.isActive && driver.status != 'AVAILABLE').toList(),
                              shipments: shipments.asData?.value ?? const <Shipment>[],
                              admin: admin,
                            ),
                          ),
                          const SizedBox(height: 12),
                          vehicles.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (error, _) => Text(error.toString(), style: const TextStyle(color: AppColors.danger)),
                            data: (items) => _vehicleMenu(items.where((vehicle) => vehicle.status == 'AVAILABLE').toList()),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: AppColors.danger)),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _canAssign(drivers, vehicles) ? _assign : null,
                            style: FilledButton.styleFrom(backgroundColor: _Ink.blue, foregroundColor: Colors.white),
                            child: Text(_submitting ? 'Assigning…' : 'Assign'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _canAssign(AsyncValue<List<DriverProfile>> drivers, AsyncValue<List<VehicleRecord>> vehicles) {
    if (_submitting) {
      return false;
    }
    final freeDrivers = drivers.asData?.value.where((driver) => driver.status == 'AVAILABLE' && driver.isActive) ?? const [];
    final freeVehicles = vehicles.asData?.value.where((vehicle) => vehicle.status == 'AVAILABLE') ?? const [];
    return freeDrivers.isNotEmpty && freeVehicles.isNotEmpty;
  }

  Widget _driverMenu(
    List<DriverProfile> drivers, {
    required List<DriverProfile> busy,
    required List<Shipment> shipments,
    required bool admin,
  }) {
    if (drivers.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No driver is free. Each driver below already has an active shipment.',
            style: TextStyle(color: _Ink.muted, height: 1.35),
          ),
          const SizedBox(height: 8),
          for (final driver in busy)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${driver.name} · ${prettyLabel(driver.status)}${_currentJob(shipments, driver.id)}',
                style: const TextStyle(color: _Ink.text),
              ),
            ),
          TextButton(
            onPressed: () => context.push(admin ? AppRoutes.adminDriverNew : AppRoutes.managerDriverNew),
            child: const Text('Add a driver'),
          ),
        ],
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _driverId,
      dropdownColor: _Ink.card,
      style: const TextStyle(color: _Ink.text),
      decoration: _field('Driver'),
      items: [
        for (final driver in drivers) DropdownMenuItem(value: driver.id, child: Text(driver.name)),
      ],
      onChanged: (value) => setState(() => _driverId = value),
    );
  }

  Widget _vehicleMenu(List<VehicleRecord> vehicles) {
    if (vehicles.isEmpty) {
      return const Text('No available vehicles.', style: TextStyle(color: _Ink.muted));
    }
    return DropdownButtonFormField<String>(
      initialValue: _vehicleId,
      dropdownColor: _Ink.card,
      style: const TextStyle(color: _Ink.text),
      decoration: _field('Vehicle'),
      items: [
        for (final vehicle in vehicles)
          DropdownMenuItem(value: vehicle.id, child: Text('${vehicle.vehicleNumber} · ${vehicle.model}')),
      ],
      onChanged: (value) => setState(() => _vehicleId = value),
    );
  }

  String _currentJob(List<Shipment> shipments, String driverId) {
    for (final shipment in shipments) {
      if (shipment.assignedDriverId == driverId && shipment.isActive) {
        return ' · ${shipment.trackingNumber}';
      }
    }
    return '';
  }

  InputDecoration _field(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _Ink.muted),
      filled: true,
      fillColor: _Ink.panel,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _Ink.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _Ink.blue)),
    );
  }
}

class _Ink {
  static const bg = Color(0xFF10141C);
  static const panel = Color(0xFF171C26);
  static const card = Color(0xFF1E2531);
  static const line = Color(0xFF2C3544);
  static const text = Color(0xFFF5F7FB);
  static const muted = Color(0xFF9AA6B8);
  static const blue = Color(0xFF2563EB);
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Ink.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Ink.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _Ink.muted, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 88, child: Text(label, style: const TextStyle(color: _Ink.muted))),
          Expanded(child: Text(value, style: const TextStyle(color: _Ink.text, fontWeight: FontWeight.w600, height: 1.35))),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(prettyLabel(value), style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w700)),
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
          Text(message, style: const TextStyle(color: _Ink.text)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
