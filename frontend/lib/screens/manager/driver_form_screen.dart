import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/logistics_providers.dart';
import '../../services/logistics_service.dart';

class DriverFormScreen extends ConsumerStatefulWidget {
  const DriverFormScreen({super.key});

  @override
  ConsumerState<DriverFormScreen> createState() => _DriverFormScreenState();
}

class _DriverFormScreenState extends ConsumerState<DriverFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _license = TextEditingController();
  final _expiry = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _license.dispose();
    _expiry.dispose();
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
      await ref.read(logisticsServiceProvider).createDriver(
        name: _name.text,
        email: _email.text,
        password: _password.text,
        phone: _phone.text,
        licenseNumber: _license.text,
        licenseExpiry: _expiry.text.trim(),
      );
      ref.invalidate(driverListProvider);
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
      appBar: AppBar(title: const Text('New driver')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => (value == null || value.trim().length < 2) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) =>
                  (value == null || !value.contains('@')) ? 'Enter an email' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Temporary password'),
              validator: (value) => (value == null || value.length < 8) ? 'Use at least 8 characters' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _license,
              decoration: const InputDecoration(labelText: 'License number'),
              validator: (value) =>
                  (value == null || value.trim().length < 3) ? 'Enter the license number' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _expiry,
              decoration: const InputDecoration(labelText: 'License expiry (YYYY-MM-DD)'),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (DateTime.tryParse(text) == null) {
                  return 'Use YYYY-MM-DD';
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
              child: Text(_submitting ? 'Saving…' : 'Save driver'),
            ),
          ],
        ),
      ),
    );
  }
}
