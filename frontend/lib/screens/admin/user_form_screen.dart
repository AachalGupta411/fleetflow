import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/logistics_providers.dart';
import '../../services/logistics_service.dart';

class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({super.key});

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String _role = 'CUSTOMER';
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
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
      await ref.read(logisticsServiceProvider).createUser(
        name: _name.text,
        email: _email.text,
        password: _password.text,
        phone: _phone.text,
        role: _role,
      );
      ref.invalidate(userListProvider);
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
      appBar: AppBar(title: const Text('New user')),
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
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (value) => (value == null || value.length < 8) ? 'Use at least 8 characters' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                DropdownMenuItem(value: 'FLEET_MANAGER', child: Text('Fleet Manager')),
                DropdownMenuItem(value: 'CUSTOMER', child: Text('Customer')),
              ],
              onChanged: (value) => setState(() => _role = value ?? 'CUSTOMER'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Drivers are created from the Drivers screen so a license can be recorded.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Saving…' : 'Save user'),
            ),
          ],
        ),
      ),
    );
  }
}
