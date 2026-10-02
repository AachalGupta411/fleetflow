import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../models/app_user.dart';
import '../providers/api_providers.dart';

class AuthService {
  AuthService(this._client);

  final ApiClient _client;

  Future<AuthSession> login(String email, String password) async {
    final data = await _client.send(
      'POST',
      '/api/v1/auth/login',
      body: {'email': email.trim(), 'password': password},
      reportUnauthorized: false,
    );
    return _session(data);
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final data = await _client.send(
      'POST',
      '/api/v1/auth/register',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
      reportUnauthorized: false,
    );
    return _session(data);
  }

  Future<AppUser> currentUser() {
    return _client
        .send('GET', '/api/v1/auth/me', reportUnauthorized: false)
        .then((data) => AppUser.fromJson(data as Map<String, dynamic>));
  }

  AuthSession _session(dynamic data) {
    final json = data as Map<String, dynamic>;
    return AuthSession(
      token: json['access_token'] as String,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiClientProvider));
});
