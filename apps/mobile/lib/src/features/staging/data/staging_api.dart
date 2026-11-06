import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/staging_models.dart';

/// Lapisan data Staging Pump (staging.py).
class StagingApi {
  final Dio _dio;
  StagingApi(this._dio);

  Future<List<StagingGroup>> groups(String period) async {
    final r = await _dio.get('/v1/staging/groups',
        queryParameters: {'period': period});
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list
        .map((e) => StagingGroup.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<int> createGroup(Map<String, dynamic> body) async {
    final r = await _dio.post('/v1/staging/groups', data: body);
    return ((r.data as Map)['id'] as num?)?.toInt() ?? 0;
  }

  Future<void> patchGroup(int id, Map<String, dynamic> body) =>
      _dio.patch('/v1/staging/groups/$id', data: body);

  Future<void> deleteGroup(int id) => _dio.delete('/v1/staging/groups/$id');

  Future<void> addPump(
    int gid, {
    required String pumpCn,
    required int roleOrder,
    required String period,
  }) =>
      _dio.post('/v1/staging/groups/$gid/pumps',
          data: {'pump_cn': pumpCn, 'role_order': roleOrder},
          queryParameters: {'period': period});

  Future<void> deletePump(int id) => _dio.delete('/v1/staging/pumps/$id');

  Future<void> movePump(int pumpId, int toGroupId, int toRoleOrder) =>
      _dio.post('/v1/staging/move', data: {
        'pump_id': pumpId,
        'to_group_id': toGroupId,
        'to_role_order': toRoleOrder,
      });

  Future<void> copyConfig(String fromPeriod, String toPeriod) =>
      _dio.post('/v1/staging/copy',
          data: {'from_period': fromPeriod, 'to_period': toPeriod});

  Future<List<StagingChange>> changes(String? period, {int? groupId}) async {
    final r = await _dio.get('/v1/staging/changes', queryParameters: {
      if (period != null && period.isNotEmpty) 'period': period,
      if (groupId != null) 'group_id': groupId,
    });
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list
        .map((e) => StagingChange.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Cek CN pump ada di master equipment kategori PUMPING (web searchStagingEquipment).
  Future<bool> equipmentExists(String cn) async {
    final r = await _dio.get('/v1/staging/equipment', queryParameters: {'q': cn});
    final list = ((r.data as Map)['data'] as List? ?? []);
    return list.any((e) => '${(e as Map)['cn']}' == cn);
  }
}

final stagingApiProvider =
    Provider<StagingApi>((ref) => StagingApi(ref.watch(dioProvider)));
