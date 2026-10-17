import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/mom_models.dart';

/// API client untuk /v1/mom — meetings + action items CRUD.
class MomApi {
  final Dio _dio;
  MomApi(this._dio);

  Future<List<MomMeeting>> listMeetings({String? status, String? category}) async {
    final r = await _dio.get('/v1/mom/meetings', queryParameters: {
      if (status != null) 'status': status,
      if (category != null) 'category': category,
    });
    final list = ((r.data as Map)['data'] as List?) ?? [];
    return list.map((e) => MomMeeting.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<MomMeetingDetail> getMeeting(int id) async {
    final r = await _dio.get('/v1/mom/meetings/$id');
    return MomMeetingDetail.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<int> createMeeting({
    required String title,
    required String meetingDate,
    String? location,
    String category = 'Operasional',
  }) async {
    final r = await _dio.post('/v1/mom/meetings', data: {
      'title': title,
      'meeting_date': meetingDate,
      if (location != null) 'location': location,
      'category': category,
      'status': 'open',
    });
    return (r.data as Map)['id'] as int;
  }

  Future<void> patchMeeting(int id, Map<String, dynamic> body) async {
    await _dio.patch('/v1/mom/meetings/$id', data: body);
  }

  Future<void> deleteMeeting(int id) async {
    await _dio.delete('/v1/mom/meetings/$id');
  }

  Future<int> addItem(int meetingId, {
    required String description,
    String? pic,
    String? dueDate,
    String priority = 'medium',
    String status = 'open',
    String? notes,
  }) async {
    final r = await _dio.post('/v1/mom/meetings/$meetingId/items', data: {
      'description': description,
      if (pic != null) 'pic': pic,
      if (dueDate != null) 'due_date': dueDate,
      'priority': priority,
      'status': status,
      if (notes != null) 'notes': notes,
    });
    return (r.data as Map)['id'] as int;
  }

  Future<void> patchItem(int id, Map<String, dynamic> body) async {
    await _dio.patch('/v1/mom/items/$id', data: body);
  }

  Future<void> deleteItem(int id) async {
    await _dio.delete('/v1/mom/items/$id');
  }
}

final momApiProvider = Provider<MomApi>((ref) => MomApi(ref.watch(dioProvider)));
