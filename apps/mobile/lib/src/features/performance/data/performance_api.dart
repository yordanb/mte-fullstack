import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/perf_models.dart';

/// Lapisan data Performance: GET /v1/dbr/stats (dbr.py:136-202).
/// Default server: 90 hari, mingguan, exclude_continue=true.
class PerformanceApi {
  final Dio _dio;
  PerformanceApi(this._dio);

  Future<PerfStats> stats({
    String? dateFrom,
    String? dateTo,
    String granularity = 'week',
    String? prefix,
    String? code,
    bool excludeContinue = true,
  }) async {
    final r = await _dio.get('/v1/dbr/stats', queryParameters: {
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      'granularity': granularity,
      if (prefix != null && prefix.isNotEmpty) 'prefix': prefix,
      if (code != null && code.isNotEmpty) 'code': code,
      'exclude_continue': excludeContinue,
    });
    return PerfStats.fromJson((r.data as Map).cast<String, dynamic>());
  }
}

final performanceApiProvider =
    Provider<PerformanceApi>((ref) => PerformanceApi(ref.watch(dioProvider)));
