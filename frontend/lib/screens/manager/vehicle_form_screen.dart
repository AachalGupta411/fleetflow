import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/logistics_providers.dart';
import '../../services/logistics_service.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key});

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _type = TextEditingController();
  final _model = TextEditingController();
  final _capacity = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _number.dispose();
    _type.dispose();
    _model.dispose();
    _capacity.dispose();
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
      await ref.read(logisticsServiceProvider).createVehicle(
        vehicleNumber: _number.text,
        vehicleType: _type.text,
        model: _model.text,
        capacity: int.parse(_capacity.text.trim()),
      );
      ref.invalidate(vehicleListProvider);
      if (mounted) {
        context.pop();
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
    return Scaffold(
      appBar: AppBar(title: const Text('New vehicle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _number,
              decoration: const InputDecoration(labelText: 'Vehicle number'),
              validator: (value) =>
                  (value == null || value.trim().length < 3) ? 'Enter the vehicle number' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              validator: (value) => (value == null || value.trim().length < 2) ? 'Enter a type' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _model,
              decoration: const InputDecoration(labelText: 'Model'),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a model' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacity (kg)'),
              validator: (value) {
                final parsed = int.tryParse(value?.trim() ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Enter capacity in kilograms';
                }
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Saving…' : 'Save vehicle'),
            ),
          ],
        ),
      ),
    );
  }
}
