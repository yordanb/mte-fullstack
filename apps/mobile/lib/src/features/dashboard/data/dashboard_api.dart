import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mte_data_center/src/core/network/dio_client.dart';

/// Satu baris dashboard: 43 kolom SELECT latest-per-unit (results.py:66-74).
/// Semua nullable karena sel impor bisa NULL (ND/`-`).
class LabRow {
  final String labNo;
  final String vesselId;
  final String unitId;
  final String? model;
  final String? sampleDate;
  final String? dateTaken;
  final String? condition;

  const LabRow({
    required this.labNo,
    required this.vesselId,
    required this.unitId,
    this.model,
    this.sampleDate,
    this.dateTaken,
    this.condition,
  });

  factory LabRow.fromJson(Map<String, dynamic> j) => LabRow(
        labNo: '${j['lab_no'] ?? ''}',
        vesselId: '${j['vesselid'] ?? ''}',
        unitId: '${j['unit_id'] ?? ''}',
        model: j['model']?.toString(),
        sampleDate: j['sample_date']?.toString(),
        dateTaken: j['date_taken']?.toString(),
        condition: j['condition']?.toString(),
      );
}

/// Label last update dari GET /v1/imports/latest (imports.py:143-152).
/// Kosong ({}) bila belum ada -> null.
class ImportStatus {
  final String id;
  final String filename;
  final String status;
  final int totalRows;
  final int okRows;
  final String? uploadedBy;
  final String? createdAt;

  const ImportStatus({
    required this.id,
    required this.filename,
    required this.status,
    required this.totalRows,
    required this.okRows,
    this.uploadedBy,
    this.createdAt,
  });

  static ImportStatus? fromJson(Map<String, dynamic>? j) {
    if (j == null || j['id'] == null) return null;
    return ImportStatus(
      id: '${j['id']}',
      filename: '${j['filename'] ?? ''}',
      status: '${j['status'] ?? ''}',
      totalRows: (j['total_rows'] as num?)?.toInt() ?? 0,
      okRows: (j['ok_rows'] as num?)?.toInt() ?? 0,
      uploadedBy: j['uploaded_by']?.toString(),
      createdAt: j['created_at']?.toString(),
    );
  }
}

/// Lapisan data dashboard: GET /results/latest-per-unit, /results, /imports/latest.
class DashboardApi {
  final Dio _dio;
  DashboardApi(this._dio);

  Future<List<LabRow>> latestPerUnit({int limit = 200, String? prefix, String? condition}) async {
    final r = await _dio.get('/v1/results/latest-per-unit', queryParameters: {
      'limit': limit,
      if (prefix != null && prefix.isNotEmpty) 'prefix': prefix,
      if (condition != null && condition.isNotEmpty) 'condition': condition,
    });
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list.map((e) => LabRow.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<List<LabRow>> search(String vessel, [String? unit]) async {
    final r = await _dio.get('/v1/results', queryParameters: {
      'vesselid': vessel,
      if (unit != null && unit.isNotEmpty) 'unit_id': unit,
      'limit': 20,
    });
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list.map((e) => LabRow.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<ImportStatus?> latestImport() async {
    final r = await _dio.get('/v1/imports/latest');
    if (r.data is Map) {
      return ImportStatus.fromJson((r.data as Map).cast<String, dynamic>());
    }
    return null;
  }
}

final dashboardApiProvider = Provider<DashboardApi>((ref) => DashboardApi(ref.watch(dioProvider)));
