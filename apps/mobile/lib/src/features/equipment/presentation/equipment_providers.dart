import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;

import '../data/equipment_api.dart';
import '../domain/equipment_models.dart';

const int eqPageSize = 20;

/// Filter Equipment meniru EquipmentPage web. aktif: '' = semua,
/// '1' = aktif, '0' = nonaktif.
class EqFilter {
  final String q;
  final String cat;
  final String aktif;
  final String sort;
  final String order;
  final int page;

  const EqFilter({
    this.q = '',
    this.cat = '',
    this.aktif = '',
    this.sort = 'cn',
    this.order = 'asc',
    this.page = 1,
  });

  EqFilter copyWith({
    String? q,
    String? cat,
    String? aktif,
    String? sort,
    String? order,
    int? page,
  }) =>
      EqFilter(
        q: q ?? this.q,
        cat: cat ?? this.cat,
        aktif: aktif ?? this.aktif,
        sort: sort ?? this.sort,
        order: order ?? this.order,
        page: page ?? this.page,
      );
}

class EqFilterNotifier extends Notifier<EqFilter> {
  @override
  EqFilter build() => const EqFilter();

  void apply({String? q, String? cat, String? aktif}) {
    state = state.copyWith(q: q, cat: cat, aktif: aktif, page: 1);
  }

  void toggleSort(String key) {
    final o = state.sort == key && state.order == 'asc' ? 'desc' : 'asc';
    state = state.copyWith(sort: key, order: o, page: 1);
  }

  void setPage(int p) => state = state.copyWith(page: p);
}

final eqFilterProvider = NotifierProvider<EqFilterNotifier, EqFilter>(EqFilterNotifier.new);

Future<T> _guard<T>(Ref ref, Future<T> Function() fn) async {
  try {
    return await fn();
  } on DioException catch (e) {
    if (e.response?.statusCode == 401) {
      await ref.read(authProvider.notifier).forceLogout();
    }
    throw apiMessage(e);
  } catch (e) {
    throw apiMessage(e);
  }
}

final eqListProvider = FutureProvider<EqPageResult>((ref) async {
  final f = ref.watch(eqFilterProvider);
  final api = ref.watch(equipmentApiProvider);
  return _guard(
    ref,
    () => api.list(
      search: f.q.isEmpty ? null : f.q,
      category: f.cat.isEmpty ? null : f.cat,
      aktif: f.aktif == '' ? null : f.aktif == '1',
      sort: f.sort,
      order: f.order,
      page: f.page,
      pageSize: eqPageSize,
    ),
  );
});

final eqDetailProvider = FutureProvider.family<Equipment, String>((ref, cn) async {
  final api = ref.watch(equipmentApiProvider);
  return _guard(ref, () => api.detail(cn));
});

void invalidateEqLists(WidgetRef ref) {
  ref.invalidate(eqListProvider);
}
