import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/storage/token_storage.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'api_providers.dart';

class AuthSnapshot {
  const AuthSnapshot({this.user, this.ready = false});

  final AppUser? user;
  final bool ready;
}

class AuthController extends Notifier<AuthSnapshot> {
  @override
  AuthSnapshot build() {
    _restore();
    return const AuthSnapshot();
  }

  Future<void> _restore() async {
    final storage = ref.read(tokenStorageProvider);
    final store = ref.read(tokenStoreProvider);
    final token = await storage.read();
    if (token == null || token.isEmpty) {
      state = const AuthSnapshot(ready: true);
      return;
    }
    store.token = token;
    try {
      final user = await ref.read(authServiceProvider).currentUser();
      await storage.writeProfile(jsonEncode(user.toJson()));
      state = AuthSnapshot(user: user, ready: true);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        store.token = null;
        await storage.delete();
        ref.read(sessionNoticeProvider.notifier).expire();
        state = const AuthSnapshot(ready: true);
        return;
      }
      state = AuthSnapshot(user: await _cachedUser(storage), ready: true);
    } catch (_) {
      state = AuthSnapshot(user: await _cachedUser(storage), ready: true);
    }
  }

  Future<AppUser?> _cachedUser(TokenStorage storage) async {
    final raw = await storage.readProfile();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final session = await ref.read(authServiceProvider).login(email, password);
      await _persist(session);
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final session = await ref.read(authServiceProvider).register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      await _persist(session);
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  Future<void> logout() async {
    ref.read(tokenStoreProvider).token = null;
    await ref.read(tokenStorageProvider).delete();
    state = const AuthSnapshot(ready: true);
  }

  Future<void> _persist(AuthSession session) async {
    ref.read(tokenStoreProvider).token = session.token;
    final storage = ref.read(tokenStorageProvider);
    await storage.write(session.token);
    await storage.writeProfile(jsonEncode(session.user.toJson()));
    ref.read(sessionNoticeProvider.notifier).clear();
    state = AuthSnapshot(user: session.user, ready: true);
  }
}

final authProvider = NotifierProvider<AuthController, AuthSnapshot>(
  AuthController.new,
);

class SessionNotice extends Notifier<String?> {
  @override
  String? build() => null;

  void expire() {
    state = 'Your session expired. Sign in again.';
  }

  void clear() => state = null;
}

final sessionNoticeProvider = NotifierProvider<SessionNotice, String?>(SessionNotice.new);

final sessionBinderProvider = Provider<void>((ref) {
  final client = ref.read(apiClientProvider);
  client.onUnauthorized = () {
    if (ref.read(authProvider).user == null) {
      return;
    }
    ref.read(sessionNoticeProvider.notifier).expire();
    ref.read(authProvider.notifier).logout();
  };
  ref.onDispose(() {
    client.onUnauthorized = null;
  });
});
