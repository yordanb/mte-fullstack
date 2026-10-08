import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/dbr_models.dart';

/// Lapisan data DBR (dbr.py): GET /dbr/records (paginasi server),
/// GET /dbr/codes (dropdown). CONTINUE difilter di client seperti web.
class DbrApi {
  final Dio _dio;
  DbrApi(this._dio);

  Future<DbrPageResult> records({
    String? dateFrom,
    String? dateTo,
    String? cn,
    String? code,
    bool excludeContinue = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    final r = await _dio.get('/v1/dbr/records', queryParameters: {
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      if (cn != null && cn.isNotEmpty) 'cn': cn,
      if (code != null && code.isNotEmpty) 'code': code,
      if (excludeContinue) 'exclude_continue': true,
      'page': page,
      'page_size': pageSize,
    });
    final m = (r.data as Map).cast<String, dynamic>();
    final list = (m['data'] as List? ?? []);
    return DbrPageResult(
      total: (m['total'] as num?)?.toInt() ?? 0,
      page: (m['page'] as num?)?.toInt() ?? page,
      rows: list.map((e) => DbrRow.fromJson((e as Map).cast<String, dynamic>())).toList(),
    );
  }

  Future<List<String>> codes() async {
    final r = await _dio.get('/v1/dbr/codes');
    final list = (((r.data as Map)['data']) as List? ?? []);
    return list.map((e) => '$e').toList();
  }
}

final dbrApiProvider = Provider<DbrApi>((ref) => DbrApi(ref.watch(dioProvider)));
