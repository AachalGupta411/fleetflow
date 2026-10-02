import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/delivery_rules.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/delivery_providers.dart';
import '../../providers/logistics_providers.dart';
import '../../providers/tracking_providers.dart';
import '../../services/delivery_service.dart';
import '../../widgets/fleet_scaffold.dart';

class FailDeliveryScreen extends ConsumerStatefulWidget {
  const FailDeliveryScreen({super.key, required this.shipmentId});

  final String shipmentId;

  @override
  ConsumerState<FailDeliveryScreen> createState() => _FailDeliveryScreenState();
}

class _FailDeliveryScreenState extends ConsumerState<FailDeliveryScreen> {
  String? _reason;
  final _notes = TextEditingController();
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FleetScaffold(
      title: 'Report failure',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: [
              for (final entry in failureReasons.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => _reason = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Saving…' : 'Report failed delivery'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final error = validateFailure(reason: _reason, notes: _notes.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final deliveryId = ref.read(shipmentProvider(widget.shipmentId)).value?.deliveryId;
      if (deliveryId == null) {
        setState(() => _error = 'This shipment has no delivery record yet.');
        return;
      }
      final fix = await ref.read(trackingSessionProvider.notifier).captureFix();
      final queued = await ref.read(deliveryServiceProvider).fail(
            deliveryId: deliveryId,
            reason: _reason!,
            notes: _notes.text.trim(),
            latitude: fix?.latitude,
            longitude: fix?.longitude,
          );
      ref.read(pendingActionsProvider.notifier).setCount(await ref.read(deliveryServiceProvider).pendingCount());
      ref.invalidate(shipmentProvider(widget.shipmentId));
      ref.invalidate(shipmentListProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(queued ? 'Saved on this device. It will sync when you are back online.' : 'Delivery marked failed.')),
      );
      context.pop();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
