import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/app_config.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/riwayat_models.dart';

/// Lapisan data Riwayat (riwayat.py): issue + progress + parts + foto evidence.
class RiwayatApi {
  final Dio _dio;
  RiwayatApi(this._dio);

  /// URL foto evidence progress dengan token (web riwayatProgressPhotoUrl).
  static String progressPhotoUrl(int pid, int phid, String token) =>
      '${AppConfig.baseUrl}/v1/riwayat/progress/$pid/photos/$phid?token=$token';

  /// URL foto evidence part dengan token (web riwayatPartPhotoUrl).
  static String partPhotoUrl(int ptid, int phid, String token) =>
      '${AppConfig.baseUrl}/v1/riwayat/parts/$ptid/photos/$phid?token=$token';

  Future<List<RiwayatIssue>> issues({
    String? status,
    String? category,
    String? cn,
  }) async {
    final r = await _dio.get('/v1/riwayat/issues', queryParameters: {
      if (status != null && status.isNotEmpty && status != 'all') 'status': status,
      if (category != null && category.isNotEmpty) 'category': category,
      if (cn != null && cn.isNotEmpty) 'cn': cn,
    });
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list
        .map((e) => RiwayatIssue.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<RiwayatIssueFull> issue(int id) async {
    final r = await _dio.get('/v1/riwayat/issues/$id');
    return RiwayatIssueFull.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<int> createIssue(Map<String, dynamic> body) async {
    final r = await _dio.post('/v1/riwayat/issues', data: body);
    return ((r.data as Map)['id'] as num?)?.toInt() ?? 0;
  }

  Future<void> patchIssue(int id, Map<String, dynamic> body) =>
      _dio.patch('/v1/riwayat/issues/$id', data: body);

  Future<void> deleteIssue(int id) => _dio.delete('/v1/riwayat/issues/$id');

  Future<void> addProgress(int issueId, Map<String, dynamic> body) =>
      _dio.post('/v1/riwayat/issues/$issueId/progress', data: body);

  Future<void> patchProgress(int id, Map<String, dynamic> body) =>
      _dio.patch('/v1/riwayat/progress/$id', data: body);

  Future<void> deleteProgress(int id) =>
      _dio.delete('/v1/riwayat/progress/$id');

  Future<void> addPart(int issueId, Map<String, dynamic> body) =>
      _dio.post('/v1/riwayat/issues/$issueId/parts', data: body);

  Future<void> patchPart(int id, Map<String, dynamic> body) =>
      _dio.patch('/v1/riwayat/parts/$id', data: body);

  Future<void> deletePart(int id) => _dio.delete('/v1/riwayat/parts/$id');

  /// Part yang terkait satu progress (web fetchRiwayatPartsByProgress).
  Future<List<RiwayatPart>> partsByProgress(int pid) async {
    final r = await _dio.get('/v1/riwayat/progress/$pid/parts');
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list
        .map((e) => RiwayatPart.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> addPartToProgress(int pid, Map<String, dynamic> body) =>
      _dio.post('/v1/riwayat/progress/$pid/parts', data: body);

  // ── Foto evidence ──────────────────────────────────────────────
  Future<List<RiwayatPhoto>> progressPhotos(int pid) async {
    final r = await _dio.get('/v1/riwayat/progress/$pid/photos');
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list
        .map((e) => RiwayatPhoto.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> addProgressPhotos(
      int pid, List<String> paths, List<String> names) async {
    final fd = FormData();
    for (var i = 0; i < paths.length; i++) {
      fd.files.add(MapEntry(
          'files', await MultipartFile.fromFile(paths[i], filename: names[i])));
    }
    await _dio.post('/v1/riwayat/progress/$pid/photos', data: fd);
  }

  Future<void> deleteProgressPhoto(int pid, int phid) =>
      _dio.delete('/v1/riwayat/progress/$pid/photos/$phid');

  Future<void> patchProgressPhotoNotes(int pid, int phid, String? notes) =>
      _dio.patch('/v1/riwayat/progress/$pid/photos/$phid/notes',
          data: {'notes': notes});

  Future<List<RiwayatPhoto>> partPhotos(int ptid) async {
    final r = await _dio.get('/v1/riwayat/parts/$ptid/photos');
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list
        .map((e) => RiwayatPhoto.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> addPartPhotos(
      int ptid, List<String> paths, List<String> names) async {
    final fd = FormData();
    for (var i = 0; i < paths.length; i++) {
      fd.files.add(MapEntry(
          'files', await MultipartFile.fromFile(paths[i], filename: names[i])));
    }
    await _dio.post('/v1/riwayat/parts/$ptid/photos', data: fd);
  }

  Future<void> deletePartPhoto(int ptid, int phid) =>
      _dio.delete('/v1/riwayat/parts/$ptid/photos/$phid');

  Future<void> patchPartPhotoNotes(int ptid, int phid, String? notes) =>
      _dio.patch('/v1/riwayat/parts/$ptid/photos/$phid/notes',
          data: {'notes': notes});
}

final riwayatApiProvider =
    Provider<RiwayatApi>((ref) => RiwayatApi(ref.watch(dioProvider)));
