import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/safety_models.dart';

/// Lapisan data Safety Bomak + R1BI (safety.py, r1bi.py).
/// Sync (POST) diberi timeout panjang: bisa menit (±16rb baris R1BI),
/// sedangkan default Dio hanya 30 detik.
Options _longTimeout() => Options(
      sendTimeout: const Duration(minutes: 10),
      receiveTimeout: const Duration(minutes: 10),
    );

class SafetyApi {
  final Dio _dio;
  SafetyApi(this._dio);

  // ---- Bomak (/v1/safety) ----
  Future<({List<SafetyCoverageRow> coverage, SafetyCompliance compliance, List<String> sections})> coverage(
      int year, int month) async {
    final r = await _dio.get('/v1/safety/coverage',
        queryParameters: {'year': year, 'month': month});
    final m = (r.data as Map).cast<String, dynamic>();
    return (
      coverage: ((m['coverage'] as List? ?? [])
          .map((e) => SafetyCoverageRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList()),
      compliance: SafetyCompliance.fromJson(
          (m['compliance'] as Map?)?.cast<String, dynamic>()),
      sections: ((m['sections'] as List? ?? []).map((e) => '$e').toList()),
    );
  }

  Future<({int total, int page, List<SafetyRow> rows})> records({
    String? dateFrom,
    String? dateTo,
    String? section,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final r = await _dio.get('/v1/safety/records', queryParameters: {
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (section != null && section.isNotEmpty) 'section': section,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'page_size': pageSize,
    });
    final m = (r.data as Map).cast<String, dynamic>();
    return (
      total: (m['total'] as num?)?.toInt() ?? 0,
      page: (m['page'] as num?)?.toInt() ?? page,
      rows: ((m['data'] as List? ?? [])
          .map((e) => SafetyRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList()),
    );
  }

  Future<List<Map<String, String?>>> exportRows({
    String? dateFrom,
    String? dateTo,
    String? section,
    String? search,
  }) async {
    final r = await _dio.get('/v1/safety/export', queryParameters: {
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (section != null && section.isNotEmpty) 'section': section,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list
        .map((e) => {
              'nama': (e as Map)['mekanik_nama']?.toString(),
              'submittedAt': (e)['submitted_at']?.toString(),
            })
        .toList();
  }

  Future<SyncResult> sync() async {
    final r = await _dio.post('/v1/safety/sync', options: _longTimeout());
    return SyncResult.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<LatestSync?> latestSync() async {
    final r = await _dio.get('/v1/safety/latest-sync');
    if (r.data is Map) {
      return LatestSync.fromJson((r.data as Map).cast<String, dynamic>());
    }
    return null;
  }

  // ---- R1BI (/v1/r1bi) ----
  Future<({List<RibiCoverageRow> coverage, int total, int high, List<String> sections})> ribiCoverage(
      int year, int month) async {
    final r = await _dio.get('/v1/r1bi/coverage',
        queryParameters: {'year': year, 'month': month});
    final m = (r.data as Map).cast<String, dynamic>();
    final comp = (m['compliance'] as Map?)?.cast<String, dynamic>();
    return (
      coverage: ((m['coverage'] as List? ?? [])
          .map((e) => RibiCoverageRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList()),
      total: (comp?['total'] as num?)?.toInt() ?? 0,
      high: (comp?['high'] as num?)?.toInt() ?? 0,
      sections: ((m['sections'] as List? ?? []).map((e) => '$e').toList()),
    );
  }

  Future<({int total, int page, List<RibiRow> rows})> ribiRecords({
    String? dateFrom,
    String? dateTo,
    String? section,
    String? risk,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final r = await _dio.get('/v1/r1bi/records', queryParameters: {
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (section != null && section.isNotEmpty) 'section': section,
      if (risk != null && risk.isNotEmpty) 'risk': risk,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'page_size': pageSize,
    });
    final m = (r.data as Map).cast<String, dynamic>();
    return (
      total: (m['total'] as num?)?.toInt() ?? 0,
      page: (m['page'] as num?)?.toInt() ?? page,
      rows: ((m['data'] as List? ?? [])
          .map((e) => RibiRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList()),
    );
  }

  Future<List<Map<String, String?>>> ribiExportRows({
    String? dateFrom,
    String? dateTo,
    String? section,
    String? search,
  }) async {
    final r = await _dio.get('/v1/r1bi/export', queryParameters: {
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (section != null && section.isNotEmpty) 'section': section,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list
        .map((e) => {
              'nama': (e as Map)['nama']?.toString(),
              'tanggal': (e)['tanggal']?.toString(),
            })
        .toList();
  }

  Future<SyncResult> ribiSync() async {
    final r = await _dio.post('/v1/r1bi/sync', options: _longTimeout());
    return SyncResult.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<LatestSync?> ribiLatestSync() async {
    final r = await _dio.get('/v1/r1bi/latest-sync');
    if (r.data is Map) {
      return LatestSync.fromJson((r.data as Map).cast<String, dynamic>());
    }
    return null;
  }

  /// Thumbnail foto Google Drive publik (tanpa auth, aman untuk Image.network).
  static String driveThumb(String fileId, [int w = 400]) =>
      'https://drive.google.com/thumbnail?id=$fileId&sz=w$w';
}

final safetyApiProvider = Provider<SafetyApi>((ref) => SafetyApi(ref.watch(dioProvider)));
