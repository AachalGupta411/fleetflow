import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage(this._storage);

  static const _key = 'access_token';
  static const _profileKey = 'signed_in_profile';
  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String token) async {
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {
      // Widget tests have no platform secure-storage plugin.
    }
  }

  Future<void> delete() async {
    try {
      await _storage.delete(key: _key);
      await _storage.delete(key: _profileKey);
    } catch (_) {}
  }

  Future<String?> readProfile() async {
    try {
      return await _storage.read(key: _profileKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeProfile(String value) async {
    try {
      await _storage.write(key: _profileKey, value: value);
    } catch (_) {}
  }
}
