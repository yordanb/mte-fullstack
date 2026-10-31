import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/ss_models.dart';

class SsApi {
  final Dio _dio;
  SsApi(this._dio);

  static final _opts = Options(
    sendTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  );

  Future<Map<String, dynamic>> filters() async {
    try {
      final r = await _dio.get('/v1/ss/filters', options: _opts);
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      throw _handleDioError(e, 'filter');
    }
  }

  Future<SsKpi> kpi(SsParams p) async {
    try {
      final r = await _dio.get('/v1/ss/kpi', queryParameters: p.toQuery(), options: _opts);
      return SsKpi.fromJson(Map<String, dynamic>.from(r.data as Map));
    } on DioException catch (e) {
      throw _handleDioError(e, 'KPI');
    }
  }

  Future<SsTargetCrewResp> targetCrew(SsParams p) async {
    try {
      final r = await _dio.get('/v1/ss/target-crew', queryParameters: p.toQuery(), options: _opts);
      return SsTargetCrewResp.fromJson(Map<String, dynamic>.from(r.data as Map));
    } on DioException catch (e) {
      throw _handleDioError(e, 'target crew');
    }
  }

  Future<List<SsTrendPoint>> trend(SsParams p) async {
    try {
      final r = await _dio.get(
        '/v1/ss/trend',
        queryParameters: {...p.toQuery(), 'granularity': p.granularity},
        options: _opts,
      );
      final data = (r.data as List?) ?? const [];
      return data
          .map((e) => SsTrendPoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e, 'trend');
    }
  }

  Future<List<SsRecord>> records(SsParams p, {int page = 1, int pageSize = 50}) async {
    try {
      final r = await _dio.get(
        '/v1/ss/records',
        queryParameters: {...p.toQuery(), 'page': page, 'page_size': pageSize},
        options: _opts,
      );
      final data = ((r.data as Map)['data'] as List?) ?? const [];
      return data
          .map((e) => SsRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e, 'records');
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

final ssApiProvider = Provider<SsApi>((ref) => SsApi(ref.watch(dioProvider)));
