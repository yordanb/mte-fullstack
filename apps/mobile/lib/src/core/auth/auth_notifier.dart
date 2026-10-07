import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'permissions.dart';
import 'token_storage.dart';
import '../../features/auth/data/auth_api.dart';
import '../../core/network/dio_client.dart' show apiMessage;

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String username;
  final String role;
  final Permissions permissions;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.username = '',
    this.role = '',
    this.permissions = const Permissions({}),
    this.error,
  });

  bool get isAdmin => role == 'admin';
  bool can(String menu, String act) => permissions.can(menu, act, isAdmin: isAdmin);

  AuthState copyWith({
    AuthStatus? status,
    String? username,
    String? role,
    Permissions? permissions,
    String? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        username: username ?? this.username,
        role: role ?? this.role,
        permissions: permissions ?? this.permissions,
        error: error,
      );
}

/// State auth global: bootstrap dari token tersimpan, login/logout,
/// dan logout paksa saat 401 final (dipanggil dari UI saat API 401).
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_bootstrap);
    return const AuthState();
  }

  TokenStorage get _store => ref.read(tokenStorageProvider);
  AuthApi get _api => ref.read(authApiProvider);

  Future<void> _bootstrap() async {
    final access = await _store.readAccess();
    if (access == null || access.isEmpty) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final me = await _api.me();
      await _store.saveSession(role: me.role, permissions: me.permissions);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        username: me.username,
        role: me.role,
        permissions: Permissions.fromJson(me.permissions),
      );
    } catch (_) {
      // Token basi dan refresh sudah dicoba interceptor sekali -> logout.
      await _store.clearAll();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// Cegah double-submit via guard di login page (isLoading).
  Future<bool> login(String username, String password) async {
    try {
      final r = await _api.login(username.trim(), password);
      await _store.saveTokens(
        access: r.accessToken,
        refresh: r.refreshToken,
        role: r.role,
        username: r.username,
      );
      final me = await _api.me();
      await _store.saveSession(role: me.role, permissions: me.permissions);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        username: me.username,
        role: me.role,
        permissions: Permissions.fromJson(me.permissions),
        error: null,
      );
      ref.invalidate(permissionsProvider);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: apiMessage(e));
      return false;
    } catch (e) {
      state = state.copyWith(error: apiMessage(e));
      return false;
    }
  }

  /// Dipanggil saat API mengembalikan 401 final (refresh gagal).
  Future<void> forceLogout() async {
    await _store.clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> logout() => forceLogout();
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
