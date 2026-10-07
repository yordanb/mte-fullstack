import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';
import 'api_exception.dart';
import '../auth/token_storage.dart';

/// Dio dengan baseUrl configurable + Bearer interceptor + auto-refresh sekali
/// saat 401 via POST /v1/auth/refresh. Gagal refresh -> 401 diteruskan agar
/// AuthNotifier memaksa ke /login dan menghapus token (handoff §3).
Dio _buildDio(TokenStorage store) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (opts, handler) async {
      final t = await store.readAccess();
      if (t != null && t.isNotEmpty) {
        opts.headers['Authorization'] = 'Bearer $t';
      }
      handler.next(opts);
    },
    onError: (err, handler) async {
      final req = err.requestOptions;
      final isAuthCall = req.path.contains('/v1/auth/login') || req.path.contains('/v1/auth/refresh');
      final alreadyRetried = req.extra['retried'] == true;
      if (err.response?.statusCode == 401 && !isAuthCall && !alreadyRetried) {
        try {
          final refresh = await store.readRefresh();
          if (refresh == null || refresh.isEmpty) return handler.next(err);
          // Refresh pakai Dio polos (tanpa interceptor) agar tidak rekursi.
          final plain = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
          final r = await plain.post('/v1/auth/refresh', data: {'refresh_token': refresh});
          final access = ((r.data as Map)['access_token']) as String;
          await store.saveAccess(access);
          req.extra['retried'] = true;
          req.headers['Authorization'] = 'Bearer $access';
          final retry = await dio.fetch(req);
          return handler.resolve(retry);
        } catch (_) {
          // Refresh gagal -> biarkan 401 asli diteruskan; AuthNotifier yang logout.
          return handler.next(err);
        }
      }
      handler.next(err);
    },
  ));

  return dio;
}

final dioProvider = Provider<Dio>((ref) => _buildDio(ref.watch(tokenStorageProvider)));

/// Helper: ubah DioException menjadi pesan `detail` server untuk UI.
String apiMessage(Object e) {
  if (e is DioException) return ApiException.fromDio(e).message;
  if (e is ApiException) return e.message;
  return e.toString();
}
