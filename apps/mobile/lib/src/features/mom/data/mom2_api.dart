import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/mom2_models.dart';

/// API client untuk /v1/mom2 — MOM Meeting Weekly SPEX Pumping.
/// Scope mobile: baca daftar meeting + detail item (input/import tetap web).
class Mom2Api {
  final Dio _dio;
  Mom2Api(this._dio);

  Future<List<Mom2Meeting>> listMeetings() async {
    final r = await _dio.get('/v1/mom2/meetings');
    final list = ((r.data as Map)['data'] as List?) ?? [];
    return list
        .map((e) => Mom2Meeting.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Mom2MeetingDetail> getMeeting(int id) async {
    final r = await _dio.get('/v1/mom2/meetings/$id');
    return Mom2MeetingDetail.fromJson((r.data as Map).cast<String, dynamic>());
  }
}

final mom2ApiProvider =
    Provider<Mom2Api>((ref) => Mom2Api(ref.watch(dioProvider)));
