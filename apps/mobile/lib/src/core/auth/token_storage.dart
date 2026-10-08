import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _kAccess = 'mte_access';
const _kRefresh = 'mte_refresh';
const _kRole = 'mte_role';
const _kUsername = 'mte_username';
const _kPerm = 'mte_perm';
const _kTheme = 'mte_theme';

/// Penyimpanan token + sesi di flutter_secure_storage.
/// Key sesi meniru localStorage web (mte_token/mte_role/mte_perm).
class TokenStorage {
  final FlutterSecureStorage _s;
  TokenStorage([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();

  Future<String?> readAccess() => _s.read(key: _kAccess);
  Future<String?> readRefresh() => _s.read(key: _kRefresh);
  Future<String?> readRole() => _s.read(key: _kRole);
  Future<String?> readUsername() => _s.read(key: _kUsername);
  Future<String?> readPermRaw() => _s.read(key: _kPerm);
  Future<String?> readTheme() => _s.read(key: _kTheme);

  Future<void> saveTokens({
    required String access,
    required String refresh,
    required String role,
    required String username,
  }) async {
    await _s.write(key: _kAccess, value: access);
    await _s.write(key: _kRefresh, value: refresh);
    await _s.write(key: _kRole, value: role);
    await _s.write(key: _kUsername, value: username);
  }

  Future<void> saveAccess(String access) => _s.write(key: _kAccess, value: access);

  Future<void> saveSession({required String role, required Map<String, dynamic> permissions}) async {
    await _s.write(key: _kRole, value: role);
    await _s.write(key: _kPerm, value: jsonEncode(permissions));
  }

  Future<void> saveTheme(String mode) => _s.write(key: _kTheme, value: mode);

  Future<void> clearAll() async {
    await _s.delete(key: _kAccess);
    await _s.delete(key: _kRefresh);
    await _s.delete(key: _kRole);
    await _s.delete(key: _kUsername);
    await _s.delete(key: _kPerm);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Token akses saat ini (untuk URL ?token= pada foto/avatar).
final accessTokenProvider = FutureProvider<String?>((ref) async {
  return ref.watch(tokenStorageProvider).readAccess();
});
