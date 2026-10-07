import 'package:dio/dio.dart';

/// Error API yang pesannya diambil dari `detail` server (handoff §3).
/// 403 selalu dipaksa menjadi "akses ditolak".
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;

  static ApiException fromDio(DioException e) {
    final code = e.response?.statusCode;
    if (code == 403) return ApiException('akses ditolak', code);
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      final msg = d is List ? d.map((x) => x.toString()).join('\n') : d.toString();
      return ApiException(msg, code);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('Waktu koneksi habis, coba lagi');
      case DioExceptionType.connectionError:
        return const ApiException('Tidak dapat terhubung ke server');
      default:
        return ApiException('Terjadi kesalahan (${code ?? 'jaringan'})');
    }
  }
}
