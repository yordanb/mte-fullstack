import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart';

import '../domain/equipment_models.dart';

/// Lapisan data Equipment (equipment.py): list + sort server, detail,
/// create (409 bila CN ada), patch parsial, import populasi.
class EquipmentApi {
  final Dio _dio;
  EquipmentApi(this._dio);

  Future<EqPageResult> list({
    String? search,
    String? category,
    bool? aktif,
    String sort = 'cn',
    String order = 'asc',
    int page = 1,
    int pageSize = 20,
  }) async {
    final r = await _dio.get('/v1/equipment', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (category != null && category.isNotEmpty) 'category': category,
      if (aktif != null) 'aktif': aktif,
      'sort': sort,
      'order': order,
      'page': page,
      'page_size': pageSize,
    });
    final m = (r.data as Map).cast<String, dynamic>();
    final list = (m['data'] as List? ?? []);
    return EqPageResult(
      total: (m['total'] as num?)?.toInt() ?? 0,
      page: (m['page'] as num?)?.toInt() ?? page,
      rows: list.map((e) => Equipment.fromJson((e as Map).cast<String, dynamic>())).toList(),
    );
  }

  Future<Equipment> detail(String cn) async {
    final r = await _dio.get('/v1/equipment/$cn');
    return Equipment.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<Equipment> create(Map<String, dynamic> body) async {
    final r = await _dio.post('/v1/equipment', data: body);
    return Equipment.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<Equipment> patch(String cn, Map<String, dynamic> body) async {
    final r = await _dio.patch('/v1/equipment/$cn', data: body);
    return Equipment.fromJson((r.data as Map).cast<String, dynamic>());
  }

  /// Import Populasi — sinkronisasi status aktif unit pompa dari file
  /// populasi equipment (.xlsx, kolom 'CN UNIT'). CN di file → aktif,
  /// CN PUMPING di luar file → nonaktif. Balasan: total_cn/activated/
  /// deactivated/not_found.
  Future<Map<String, dynamic>> importPopulasi({
    required String path,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: filename),
    });
    final r = await _dio.post('/v1/equipment/populasi', data: form);
    return Map<String, dynamic>.from(r.data as Map);
  }
}

final equipmentApiProvider =
    Provider<EquipmentApi>((ref) => EquipmentApi(ref.watch(dioProvider)));
