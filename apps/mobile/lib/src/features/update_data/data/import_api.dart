import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/import_models.dart';

/// Lapisan data Update Data: upload oli (dry-run + commit + polling),
/// upload DBR (commit + polling). Multipart `file` + onSendProgress.
class ImportApi {
  final Dio _dio;
  ImportApi(this._dio);

  Future<MultipartFile> _mp(String path, String field) async {
    final name = path.split(RegExp(r'[/\\]')).last;
    return MultipartFile.fromFile(path, filename: name);
  }

  /// POST /v1/imports?dry_run=true -> DryRunResult (validasi saja).
  Future<DryRunResult> dryRun(
    String path, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final fd = FormData.fromMap({'file': await _mp(path, 'file')});
    final r = await _dio.post('/v1/imports',
        queryParameters: {'dry_run': true},
        data: fd,
        onSendProgress: onProgress);
    return DryRunResult.fromJson((r.data as Map).cast<String, dynamic>());
  }

  /// POST /v1/imports?dry_run=false (202) -> import_id.
  Future<String> commitOil(
    String path, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final fd = FormData.fromMap({'file': await _mp(path, 'file')});
    final r = await _dio.post('/v1/imports',
        queryParameters: {'dry_run': false},
        data: fd,
        onSendProgress: onProgress);
    return '${(r.data as Map)['import_id']}';
  }

  /// POST /v1/dbr/imports (202, tanpa dry-run) -> import_id.
  Future<String> uploadDbr(
    String path, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final fd = FormData.fromMap({'file': await _mp(path, 'file')});
    final r = await _dio.post('/v1/dbr/imports',
        data: fd, onSendProgress: onProgress);
    return '${(r.data as Map)['import_id']}';
  }

  /// GET /v1/imports/{id} — polling tiap 2 detik.
  Future<ImportProgress> status(String importId) async {
    final r = await _dio.get('/v1/imports/$importId');
    return ImportProgress.fromJson((r.data as Map).cast<String, dynamic>());
  }
}

final importApiProvider = Provider<ImportApi>((ref) => ImportApi(ref.watch(dioProvider)));
