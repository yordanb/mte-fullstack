import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/hourmeter_models.dart';

/// Lapisan data Hourmeter (hourmeter.py):
/// GET /pivot (grid HM), GET /stats (ringkasan), POST /upload (multipart).
class HourmeterApi {
  final Dio _dio;
  HourmeterApi(this._dio);

  Future<HourmeterPivot> pivot({int? year, int? month}) async {
    final r = await _dio.get('/v1/hourmeter/pivot', queryParameters: {
      if (year != null) 'year': year,
      if (month != null) 'month': month,
    });
    return HourmeterPivot.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<HourmeterStats> stats() async {
    final r = await _dio.get('/v1/hourmeter/stats');
    return HourmeterStats.fromJson((r.data as Map).cast<String, dynamic>());
  }

  /// Upload file Excel HM untuk periode tahun/bulan. `path` dari file picker.
  Future<HourmeterUploadResult> upload({
    required String path,
    required String filename,
    required int year,
    required int month,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: filename),
      'year': '$year',
      'month': '$month',
    });
    final r = await _dio.post('/v1/hourmeter/upload', data: form);
    return HourmeterUploadResult.fromJson(
        (r.data as Map).cast<String, dynamic>());
  }
}

final hourmeterApiProvider =
    Provider<HourmeterApi>((ref) => HourmeterApi(ref.watch(dioProvider)));
