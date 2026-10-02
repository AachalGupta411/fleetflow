import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/hero_frame.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
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
    final error = await ref.read(authProvider.notifier).register(
      name: _name.text,
      email: _email.text,
      password: _password.text,
      phone: _phone.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HeroFrame(
      footer: const HeroStats(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.pop(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Sign in'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Create a customer account.',
              style: TextStyle(color: Colors.white, fontSize: 40, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -0.8),
            ),
            const SizedBox(height: 8),
            const Text(
              'Name, email, and a password are enough to start.',
              style: TextStyle(color: Color(0xFFE6EDF5), fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => (value == null || value.trim().length < 2) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty || !email.contains('@')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
              validator: (value) {
                final phone = value?.trim() ?? '';
                if (phone.isEmpty) {
                  return null;
                }
                final digits = phone.replaceAll(RegExp(r'\D'), '');
                if (digits.length < 8 || digits.length > 15) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (value) => (value == null || value.length < 8) ? 'Use at least 8 characters' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF121418),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(_submitting ? 'Creating account…' : 'Create account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
