import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/ewacs_models.dart';

/// Lapisan data Ewacs Performance (ewacs.py):
/// GET /filters /kpi /trend /detail, POST /import (CSV, admin/inputer).
class EwacsApi {
  final Dio _dio;
  EwacsApi(this._dio);

  Map<String, dynamic> _p({
    String? start,
    String? end,
    String? egi,
    String? crew,
    String? cn,
    String? kode,
    int? limit,
  }) =>
      {
        if (start != null && start.isNotEmpty) 'start': start,
        if (end != null && end.isNotEmpty) 'end': end,
        if (egi != null && egi.isNotEmpty) 'egi': egi,
        if (crew != null && crew.isNotEmpty) 'crew': crew,
        if (cn != null && cn.isNotEmpty) 'cn': cn,
        if (kode != null && kode.isNotEmpty) 'kode': kode,
        if (limit != null) 'limit': limit,
      };

  Future<EwacsFilters> filters() async {
    final r = await _dio.get('/v1/ewacs/filters');
    return EwacsFilters.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<EwacsKpi> kpi({
    String? start,
    String? end,
    String? egi,
    String? crew,
    String? cn,
  }) async {
    final r = await _dio.get('/v1/ewacs/kpi',
        queryParameters: _p(start: start, end: end, egi: egi, crew: crew, cn: cn));
    return EwacsKpi.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<List<EwacsTrend>> trend({
    String? start,
    String? end,
    String? egi,
    String? crew,
    String? cn,
  }) async {
    final r = await _dio.get('/v1/ewacs/trend',
        queryParameters: _p(start: start, end: end, egi: egi, crew: crew, cn: cn));
    return ((r.data as List? ?? []))
        .map((e) => EwacsTrend.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<EwacsDetail>> detail({
    String? start,
    String? end,
    String? egi,
    String? crew,
    String? cn,
    String? kode,
    int limit = 100,
  }) async {
    final r = await _dio.get('/v1/ewacs/detail',
        queryParameters: _p(
            start: start,
            end: end,
            egi: egi,
            crew: crew,
            cn: cn,
            kode: kode,
            limit: limit));
    return ((r.data as List? ?? []))
        .map((e) => EwacsDetail.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<EwacsImportResult> importCsv({
    required String path,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: filename),
    });
    final r = await _dio.post('/v1/ewacs/import', data: form);
    return EwacsImportResult.fromJson((r.data as Map).cast<String, dynamic>());
  }
}

final ewacsApiProvider =
    Provider<EwacsApi>((ref) => EwacsApi(ref.watch(dioProvider)));
