import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/app_config.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/profile_models.dart';

/// Lapisan data Profil: ganti password, upload avatar (≤5MB, multipart),
/// notifikasi (5 import + 5 aktivitas terbaru).
class ProfileApi {
  final Dio _dio;
  ProfileApi(this._dio);

  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    await _dio.patch('/v1/users/password', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  /// POST /v1/users/avatar (201 {avatar_url}). Batas 5MB dari server.
  Future<String> uploadAvatar(
    String path, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final name = path.split(RegExp(r'[/\\]')).last;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
    final slash = mime.indexOf('/');
    final fd = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        path,
        filename: name,
        contentType: DioMediaType(mime.substring(0, slash), mime.substring(slash + 1)),
      ),
    });
    final r = await _dio.post('/v1/users/avatar', data: fd, onSendProgress: onProgress);
    return '${(r.data as Map)['avatar_url']}';
  }

  Future<Notifications> notifications() async {
    final r = await _dio.get('/v1/users/notifications');
    return Notifications.fromJson((r.data as Map).cast<String, dynamic>());
  }

  /// Avatar mendukung ?token=, 404 bila belum ada foto (tampilkan inisial).
  static String avatarUrl(String username, String token) =>
      '${AppConfig.baseUrl}/v1/users/avatar/$username?token=$token';
}

final profileApiProvider = Provider<ProfileApi>((ref) => ProfileApi(ref.watch(dioProvider)));

final notificationsProvider = FutureProvider<Notifications>((ref) async {
  try {
    return await ref.watch(profileApiProvider).notifications();
  } catch (e) {
    throw apiMessage(e);
  }
});
