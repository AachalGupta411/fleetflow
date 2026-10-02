import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/hero_frame.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
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
    final error = await ref.read(authProvider.notifier).login(_email.text, _password.text);
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
    final notice = ref.watch(sessionNoticeProvider);
    return HeroFrame(
      footer: const HeroStats(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Logistics you can follow, start to finish.',
              style: TextStyle(color: Colors.white, fontSize: 44, height: 1.02, fontWeight: FontWeight.w800, letterSpacing: -1),
            ),
            const SizedBox(height: 14),
            const Text(
              'Sign in to your workspace',
              style: TextStyle(color: Color(0xFFE6EDF5), fontSize: 16),
            ),
            if (notice != null) ...[
              const SizedBox(height: 12),
              Text(notice, style: const TextStyle(color: Color(0xFFFFD7D7))),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty || !email.contains('@')) {
                  return 'Enter your email';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter your password';
                }
                return null;
              },
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
                child: Text(_submitting ? 'Signing in…' : 'Sign in'),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.push(AppRoutes.register),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(top: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Create a customer account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
