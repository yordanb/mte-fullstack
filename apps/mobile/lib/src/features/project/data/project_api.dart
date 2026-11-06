import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/app_config.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/project_models.dart';

/// Lapisan data Project (projects.py): project → stages → updates → foto.
class ProjectApi {
  final Dio _dio;
  ProjectApi(this._dio);

  /// URL foto eviden update dengan token (web projectPhotoUrl).
  static String photoUrl(String uid, String pid, String token) =>
      '${AppConfig.baseUrl}/v1/projects/updates/$uid/photos/$pid?token=$token';

  Future<ProjectPage> list({
    String? search,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final r = await _dio.get('/v1/projects', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
      'page': page,
      'page_size': pageSize,
    });
    return ProjectPage.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<Project> detail(String id) async {
    final r = await _dio.get('/v1/projects/$id');
    return Project.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<String> create(Map<String, dynamic> body) async {
    final r = await _dio.post('/v1/projects', data: body);
    return '${(r.data as Map)['id'] ?? ''}';
  }

  Future<void> patch(String id, Map<String, dynamic> body) =>
      _dio.patch('/v1/projects/$id', data: body);

  Future<void> delete(String id) => _dio.delete('/v1/projects/$id');

  Future<void> addStage(String pid, Map<String, dynamic> body) =>
      _dio.post('/v1/projects/$pid/stages', data: body);

  Future<void> patchStage(String sid, Map<String, dynamic> body) =>
      _dio.patch('/v1/projects/stages/$sid', data: body);

  Future<void> deleteStage(String sid) =>
      _dio.delete('/v1/projects/stages/$sid');

  /// Tambah update tahap dengan banyak foto (multipart, web addProjectUpdate).
  Future<void> addUpdate(
    String sid, {
    required String date,
    required int progress,
    required String status,
    String? note,
    List<String> paths = const [],
    List<String> names = const [],
    void Function(int sent, int total)? onProgress,
  }) async {
    final fd = FormData.fromMap({
      'date': date,
      'progress': '$progress',
      'status': status,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    for (var i = 0; i < paths.length; i++) {
      fd.files.add(MapEntry(
          'files', await MultipartFile.fromFile(paths[i], filename: names[i])));
    }
    await _dio.post('/v1/projects/stages/$sid/updates',
        data: fd, onSendProgress: onProgress);
  }

  Future<void> patchUpdate(String uid, Map<String, dynamic> body) =>
      _dio.patch('/v1/projects/updates/$uid', data: body);

  Future<void> deleteUpdate(String uid) =>
      _dio.delete('/v1/projects/updates/$uid');

  Future<void> deletePhoto(String uid, String pid) =>
      _dio.delete('/v1/projects/updates/$uid/photos/$pid');
}

final projectApiProvider =
    Provider<ProjectApi>((ref) => ProjectApi(ref.watch(dioProvider)));
