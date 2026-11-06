import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/yazu_models.dart';

/// Lapisan data Yazu (yazu.py) & Yazu Daily Check (yazu_dc.py).
/// Keduanya identik, hanya beda prefix: `/v1/yazu` vs `/v1/yazu-dc`.
class YazuApi {
  final Dio _dio;
  final String prefix;
  YazuApi(this._dio, this.prefix);

  Future<YazuPivot> pivot({int? year, int? month}) async {
    final r = await _dio.get('$prefix/pivot', queryParameters: {
      if (year != null) 'year': year,
      if (month != null) 'month': month,
    });
    return YazuPivot.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<YazuStats> stats() async {
    final r = await _dio.get('$prefix/stats');
    return YazuStats.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<YazuSyncResult> sync() async {
    final r = await _dio.post('$prefix/sync');
    return YazuSyncResult.fromJson((r.data as Map).cast<String, dynamic>());
  }
}

final yazuApiProvider =
    Provider<YazuApi>((ref) => YazuApi(ref.watch(dioProvider), '/v1/yazu'));

final yazuDcApiProvider = Provider<YazuApi>(
    (ref) => YazuApi(ref.watch(dioProvider), '/v1/yazu-dc'));
