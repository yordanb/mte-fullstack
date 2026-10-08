import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/fui_models.dart';

/// Lapisan data FUI (fui.py). Dossier memakai ulang DbrApi + equipment.
class FuiApi {
  final Dio _dio;
  FuiApi(this._dio);

  /// Unit (component) 1 vessel — GET /v1/results/units.
  Future<List<String>> vesselUnits(String vessel) async {
    final r = await _dio.get('/v1/results/units', queryParameters: {'vesselid': vessel});
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list.map((e) => '$e').toList();
  }

  /// Oil terakhir per unit — GET /v1/results (limit ≤ 100).
  Future<List<OilRow>> oilByUnit(String vessel, String unit, {int limit = 10}) async {
    final r = await _dio.get('/v1/results', queryParameters: {
      'vesselid': vessel,
      'unit_id': unit,
      'limit': limit,
    });
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list.map((e) => OilRow.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  /// GET /v1/fui/suggestions?category= (wajib, min 3 huruf).
  Future<List<OilRow>> suggestions(String category) async {
    final r = await _dio.get('/v1/fui/suggestions', queryParameters: {'category': category});
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list.map((e) => OilRow.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  /// POST /v1/fui/suggests -> 201 {id}. Saran wajib diisi (400 bila kosong).
  Future<String> addSuggest({required String labNo, required String suggestion, String? pic}) async {
    final r = await _dio.post('/v1/fui/suggests', data: {
      'lab_no': labNo,
      'suggestion': suggestion,
      if (pic != null && pic.isNotEmpty) 'pic': pic,
    });
    return '${(r.data as Map)['id']}';
  }

  /// GET /v1/fui/suggests?lab_no= (terbaru dulu).
  Future<List<Suggest>> history(String labNo) async {
    final r = await _dio.get('/v1/fui/suggests', queryParameters: {'lab_no': labNo});
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list.map((e) => Suggest.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  /// GET /v1/fui/suggest-report (paginasi server setelah filter).
  Future<SuggestReportPageResult> suggestReport({
    String? category,
    String? search,
    bool? hasSuggest,
    int page = 1,
    int pageSize = 20,
  }) async {
    final r = await _dio.get('/v1/fui/suggest-report', queryParameters: {
      if (category != null && category.isNotEmpty) 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
      if (hasSuggest != null) 'has_suggest': hasSuggest,
      'page': page,
      'page_size': pageSize,
    });
    final m = (r.data as Map).cast<String, dynamic>();
    final list = (m['data'] as List? ?? []);
    return SuggestReportPageResult(
      total: (m['total'] as num?)?.toInt() ?? 0,
      page: (m['page'] as num?)?.toInt() ?? page,
      rows: list
          .map((e) => SuggestReportRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

final fuiApiProvider = Provider<FuiApi>((ref) => FuiApi(ref.watch(dioProvider)));
