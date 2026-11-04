import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/ssab_models.dart';

/// Lapisan data SS AB (ss.py GET /v1/ss/ab + export CSV).
class SsabApi {
  final Dio _dio;
  SsabApi(this._dio);

  static final _opts = Options(
    sendTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  );

  /// Export bisa besar (semua baris tahun berjalan) — timeout lebih longgar.
  static final _optsExport = Options(
    sendTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
  );

  Future<SsAbResp> fetch({int? year}) async {
    try {
      final r = await _dio.get(
        '/v1/ss/ab',
        queryParameters: {if (year != null) 'year': year},
        options: _opts,
      );
      return SsAbResp.fromJson(Map<String, dynamic>.from(r.data as Map));
    } on DioException catch (e) {
      throw _handleDioError(e, 'SS AB');
    }
  }

  Future<Uint8List> exportCsv({int? year}) async {
    try {
      final r = await _dio.get(
        '/v1/ss/ab/export',
        queryParameters: {if (year != null) 'year': year},
        options: _optsExport.copyWith(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList((r.data as List).cast<int>());
    } on DioException catch (e) {
      throw _handleDioError(e, 'export SS AB');
    }
  }

  Future<Uint8List> exportWaitingCsv() async {
    try {
      final r = await _dio.get(
        '/v1/ss/ab/export-waiting',
        options: _optsExport.copyWith(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList((r.data as List).cast<int>());
    } on DioException catch (e) {
      throw _handleDioError(e, 'export SS AB waiting');
    }
  }

  Exception _handleDioError(DioException e, String context) {
    if (kIsWeb && e.type == DioExceptionType.connectionError) {
      return Exception(
        'Error jaringan saat mengambil $context. Periksa akses API/CORS.',
      );
    }
    if (e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionTimeout) {
      return Exception('Timeout saat mengambil $context. API tidak merespons.');
    }
    return Exception('Gagal mengambil $context: ${ApiException.fromDio(e).message}');
  }
}

final ssabApiProvider = Provider<SsabApi>((ref) => SsabApi(ref.watch(dioProvider)));
