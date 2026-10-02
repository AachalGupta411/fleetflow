import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/operations_service.dart';

class FuelEntryScreen extends ConsumerStatefulWidget {
  const FuelEntryScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<FuelEntryScreen> createState() => _FuelEntryScreenState();
}

class _FuelEntryScreenState extends ConsumerState<FuelEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _liters = TextEditingController();
  final _price = TextEditingController();
  final _odometer = TextEditingController();
  final _station = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _liters.dispose();
    _price.dispose();
    _odometer.dispose();
    _station.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final month = _date.month.toString().padLeft(2, '0');
    final day = _date.day.toString().padLeft(2, '0');
    try {
      await ref.read(operationsServiceProvider).recordFuel(
        vehicleId: widget.vehicleId,
        liters: _liters.text.trim(),
        pricePerLiter: _price.text.trim(),
        fuelDate: '${_date.year}-$month-$day',
        odometerKm: _odometer.text.trim(),
        fuelStation: _station.text.trim(),
        notes: _notes.text.trim(),
      );
      if (mounted) {
        context.pop();
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record fuel')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _liters,
              decoration: const InputDecoration(labelText: 'Liters'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => _positive(value, 'Enter the liters'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              decoration: const InputDecoration(labelText: 'Price per liter'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => _positive(value, 'Enter the price per liter'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _odometer,
              decoration: const InputDecoration(labelText: 'Odometer km'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _station,
              decoration: const InputDecoration(labelText: 'Fuel station'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fuel date'),
              subtitle: Text('${_date.year}-${_date.month}-${_date.day}'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  initialDate: _date,
                );
                if (picked != null) {
                  setState(() => _date = picked);
                }
              },
            ),
            if (_error != null) Text(_error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving' : 'Save fuel record'),
            ),
          ],
        ),
      ),
    );
  }
}

String? _positive(String? value, String message) {
  final parsed = num.tryParse(value?.trim() ?? '');
  if (parsed == null || parsed <= 0) {
    return message;
  }
  return null;
}
