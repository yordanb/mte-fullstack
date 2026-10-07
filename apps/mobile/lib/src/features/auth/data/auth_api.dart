import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/auth_models.dart';

/// Lapisan data auth: POST /v1/auth/login, POST /v1/auth/refresh, GET /v1/users/me.
class AuthApi {
  final Dio _dio;
  AuthApi(this._dio);

  Future<LoginResponse> login(String username, String password) async {
    final r = await _dio.post('/v1/auth/login', data: {
      'username': username,
      'password': password,
    });
    return LoginResponse.fromJson((r.data as Map).cast<String, dynamic>());
  }

  /// Body WAJIB {refresh_token} (auth.py:35-36), respons hanya {access_token}.
  Future<String> refresh(String refreshToken) async {
    final r = await _dio.post('/v1/auth/refresh', data: {
      'refresh_token': refreshToken,
    });
    return ((r.data as Map)['access_token']) as String;
  }

  Future<MeResponse> me() async {
    final r = await _dio.get('/v1/users/me');
    return MeResponse.fromJson((r.data as Map).cast<String, dynamic>());
  }
}

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(dioProvider)));
