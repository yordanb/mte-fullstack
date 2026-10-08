import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/user_models.dart';

/// Lapisan data admin: users CRUD + permissions + audit log.
class UsersApi {
  final Dio _dio;
  UsersApi(this._dio);

  Future<List<AppUser>> list() async {
    final r = await _dio.get('/v1/admin/users');
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list.map((e) => AppUser.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<void> create({required String username, required String password, required String role}) async {
    await _dio.post('/v1/admin/users', data: {
      'username': username,
      'password': password,
      'role': role,
    });
  }

  /// role/password opsional (kosong = tidak diubah, meniru UsersPage).
  Future<void> patch(String username, {String? role, String? password}) async {
    await _dio.patch('/v1/admin/users/$username', data: {
      if (role != null) 'role': role,
      if (password != null && password.isNotEmpty) 'password': password,
    });
  }

  Future<void> remove(String username) async {
    await _dio.delete('/v1/admin/users/$username');
  }

  Future<List<PermRow>> perms() async {
    final r = await _dio.get('/v1/admin/permissions');
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list.map((e) => PermRow.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<void> setPerm(PermRow row) async {
    await _dio.put('/v1/admin/permissions', data: row.toJson());
  }

  Future<AuditPageResult> audit({
    String? dateFrom,
    String? dateTo,
    String? username,
    String? path,
    int page = 1,
    int pageSize = 20,
  }) async {
    final r = await _dio.get('/v1/admin/audit', queryParameters: {
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      if (username != null && username.isNotEmpty) 'username': username,
      if (path != null && path.isNotEmpty) 'path': path,
      'page': page,
      'page_size': pageSize,
    });
    final m = (r.data as Map).cast<String, dynamic>();
    final list = (m['data'] as List? ?? []);
    return AuditPageResult(
      total: (m['total'] as num?)?.toInt() ?? 0,
      page: (m['page'] as num?)?.toInt() ?? page,
      rows: list.map((e) => AuditRow.fromJson((e as Map).cast<String, dynamic>())).toList(),
    );
  }
}

final usersApiProvider = Provider<UsersApi>((ref) => UsersApi(ref.watch(dioProvider)));
