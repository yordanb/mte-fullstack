import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/app_config.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/activity_models.dart';

/// Lapisan data Activity (activities.py):
/// GET month/recap//{id}, POST multipart, PATCH, DELETE, foto ?token=.
class ActivityApi {
  final Dio _dio;
  ActivityApi(this._dio);

  Future<Map<String, int>> monthCounts({
    required int year,
    required int month,
    String? crew,
    String? category,
  }) async {
    final r = await _dio.get('/v1/activities/month', queryParameters: {
      'year': year,
      'month': month,
      if (crew != null && crew.isNotEmpty) 'crew': crew,
      if (category != null && category.isNotEmpty) 'category': category,
    });
    final counts = ((r.data as Map)['counts'] as Map? ?? {});
    return counts.map((k, v) => MapEntry('$k', (v as num).toInt()));
  }

  Future<List<Activity>> byDate(String date) async {
    final r = await _dio.get('/v1/activities', queryParameters: {'date': date});
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list.map((e) => Activity.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<List<Activity>> recap({
    required int year,
    required int month,
    String? crew,
    String? category,
  }) async {
    final r = await _dio.get('/v1/activities/recap', queryParameters: {
      'year': year,
      'month': month,
      if (crew != null && crew.isNotEmpty) 'crew': crew,
      if (category != null && category.isNotEmpty) 'category': category,
    });
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list.map((e) => Activity.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<Activity> detail(String id) async {
    final r = await _dio.get('/v1/activities/$id');
    return Activity.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<MultipartFile> _mp(String path) async {
    final name = path.split(RegExp(r'[/\\]')).last;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
    final slash = mime.indexOf('/');
    return MultipartFile.fromFile(
      path,
      filename: name,
      contentType: DioMediaType(mime.substring(0, slash), mime.substring(slash + 1)),
    );
  }

  /// POST /v1/activities (multipart 201) -> id. crew wajib, cn uppercase.
  Future<String> create({
    required String date,
    required String title,
    required String crew,
    String? category,
    String? cn,
    String? hm,
    String? description,
    List<String> filePaths = const [],
    void Function(int sent, int total)? onProgress,
  }) async {
    final fd = FormData.fromMap({
      'date': date,
      'title': title,
      'crew': crew,
      if (category != null && category.isNotEmpty) 'category': category,
      if (cn != null && cn.isNotEmpty) 'cn': cn.toUpperCase(),
      if (hm != null && hm.trim().isNotEmpty) 'hm': hm.trim(),
      if (description != null && description.isNotEmpty) 'description': description,
      'files': [for (final p in filePaths) await _mp(p)],
    });
    final r = await _dio.post('/v1/activities', data: fd, onSendProgress: onProgress);
    return '${(r.data as Map)['id']}';
  }

  Future<void> patch(String id, Map<String, dynamic> body) async {
    await _dio.patch('/v1/activities/$id', data: body);
  }

  Future<void> remove(String id) async {
    await _dio.delete('/v1/activities/$id');
  }

  /// POST /{id}/photos — khusus admin (403 bila bukan admin).
  Future<void> addPhotos(
    String id,
    List<String> paths, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final fd = FormData.fromMap({
      'files': [for (final p in paths) await _mp(p)],
    });
    await _dio.post('/v1/activities/$id/photos', data: fd, onSendProgress: onProgress);
  }

  Future<void> deletePhoto(String aid, String pid) async {
    await _dio.delete('/v1/activities/$aid/photos/$pid');
  }

  /// Image.network tak bisa kirim header -> pakai ?token= (activities.py:236-248).
  /// baseUrl sudah termasuk /api di produksi, langsung host di dev.
  static String photoUrl(String aid, String pid, String token) =>
      '${AppConfig.baseUrl}/v1/activities/$aid/photos/$pid?token=$token';
}

final activityApiProvider = Provider<ActivityApi>((ref) => ActivityApi(ref.watch(dioProvider)));
