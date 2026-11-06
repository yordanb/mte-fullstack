import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/manpower_models.dart';

/// Lapisan data Manpower (manpower.py): periode, summary, trend, records, manage.
class ManpowerApi {
  final Dio _dio;
  ManpowerApi(this._dio);

  // ── Manpower Inovasi ──────────────────────────────────────────
  Future<List<ManpowerPeriod>> periods() async {
    final r = await _dio.get('/v1/manpower/periods');
    return ((r.data as List? ?? []))
        .map((e) => ManpowerPeriod.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<ManpowerSummary> summary({required String periode, String? dept}) async {
    final r = await _dio.get('/v1/manpower/summary', queryParameters: {
      'periode': periode,
      if (dept != null && dept.isNotEmpty) 'dept': dept,
    });
    return ManpowerSummary.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<List<ManpowerPeriod>> trend({String? dept}) async {
    final r = await _dio.get('/v1/manpower/trend', queryParameters: {
      if (dept != null && dept.isNotEmpty) 'dept': dept,
    });
    return ((r.data as List? ?? []))
        .map((e) => ManpowerPeriod.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<ManpowerRecordPage> records({
    required String periode,
    String? dept,
    String? search,
    bool? innovator,
    int page = 1,
    int pageSize = 25,
    String sort = 'nama',
    String dir = 'asc',
  }) async {
    final r = await _dio.get('/v1/manpower/records', queryParameters: {
      'periode': periode,
      if (dept != null && dept.isNotEmpty) 'dept': dept,
      if (search != null && search.isNotEmpty) 'search': search,
      if (innovator == true) 'innovator': true,
      'page': page,
      'page_size': pageSize,
      'sort': sort,
      'dir': dir,
    });
    return ManpowerRecordPage.fromJson((r.data as Map).cast<String, dynamic>());
  }

  // ── Pengelompokan (manpowermanage) ────────────────────────────
  Future<ManpowerManage> manage({
    String? periode,
    String? dept,
    String? section,
    String? crew,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 25,
    String sort = 'nama',
    String dir = 'asc',
  }) async {
    final r = await _dio.get('/v1/manpower/manage', queryParameters: {
      if (periode != null && periode.isNotEmpty) 'periode': periode,
      if (dept != null && dept.isNotEmpty) 'dept': dept,
      if (section != null && section.isNotEmpty) 'section': section,
      if (crew != null && crew.isNotEmpty) 'crew': crew,
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'page_size': pageSize,
      'sort': sort,
      'dir': dir,
    });
    return ManpowerManage.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<ManpowerProfileRow> updateProfile(String nrp, Map<String, dynamic> body) async {
    final r = await _dio.patch('/v1/manpower/manage/$nrp', data: body);
    return ManpowerProfileRow.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<int> bulkProfile(Map<String, dynamic> body) async {
    final r = await _dio.post('/v1/manpower/manage/bulk', data: body);
    return ((r.data as Map)['updated'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> autofill() async {
    final r = await _dio.post('/v1/manpower/manage/autofill', data: const {});
    return (r.data as Map).cast<String, dynamic>();
  }
}

final manpowerApiProvider =
    Provider<ManpowerApi>((ref) => ManpowerApi(ref.watch(dioProvider)));
