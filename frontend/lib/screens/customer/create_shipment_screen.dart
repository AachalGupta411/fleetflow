import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/logistics_providers.dart';
import '../../services/logistics_service.dart';

class CreateShipmentScreen extends ConsumerStatefulWidget {
  const CreateShipmentScreen({super.key});

  @override
  ConsumerState<CreateShipmentScreen> createState() => _CreateShipmentScreenState();
}

class _CreateShipmentScreenState extends ConsumerState<CreateShipmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickup = TextEditingController();
  final _delivery = TextEditingController();
  final _description = TextEditingController();
  String _priority = 'NORMAL';
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _pickup.dispose();
    _delivery.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await ref.read(logisticsServiceProvider).createShipment(
        pickupAddress: _pickup.text,
        deliveryAddress: _delivery.text,
        packageDescription: _description.text,
        priority: _priority,
      );
      ref.invalidate(shipmentListProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created ${created.trackingNumber}')),
      );
      context.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New shipment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _pickup,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Pickup address'),
              validator: (value) =>
                  (value == null || value.trim().length < 3) ? 'Enter a pickup address' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _delivery,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Delivery address'),
              validator: (value) =>
                  (value == null || value.trim().length < 3) ? 'Enter a delivery address' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Package description'),
              validator: (value) => (value == null || value.trim().length < 2)
                  ? 'Describe the package'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const [
                DropdownMenuItem(value: 'LOW', child: Text('Low')),
                DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                DropdownMenuItem(value: 'HIGH', child: Text('High')),
                DropdownMenuItem(value: 'EXPRESS', child: Text('Express')),
              ],
              onChanged: (value) => setState(() => _priority = value ?? 'NORMAL'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Creating…' : 'Create shipment'),
            ),
          ],
        ),
      ),
    );
  }
}
