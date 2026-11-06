import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;

import '../data/ewacs_api.dart';
import '../domain/ewacs_models.dart';

/// Filter Ewacs: rentang tanggal (default 30 hari) + EGI/Crew/Unit/Kode.
class EwacsFilter {
  final String start;
  final String end;
  final String egi;
  final String crew;
  final String cn;
  final String kode;

  const EwacsFilter({
    required this.start,
    required this.end,
    this.egi = '',
    this.crew = '',
    this.cn = '',
    this.kode = '',
  });

  EwacsFilter copyWith({
    String? start,
    String? end,
    String? egi,
    String? crew,
    String? cn,
    String? kode,
  }) =>
      EwacsFilter(
        start: start ?? this.start,
        end: end ?? this.end,
        egi: egi ?? this.egi,
        crew: crew ?? this.crew,
        cn: cn ?? this.cn,
        kode: kode ?? this.kode,
      );
}

/// Default: 30 hari terakhir s/d hari ini (web).
EwacsFilter defaultEwacsFilter() {
  String iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';
  final now = DateTime.now();
  return EwacsFilter(
    start: iso(now.subtract(const Duration(days: 30))),
    end: iso(now),
  );
}

class EwacsFilterNotifier extends Notifier<EwacsFilter> {
  @override
  EwacsFilter build() => defaultEwacsFilter();

  void apply({
    String? start,
    String? end,
    String? egi,
    String? crew,
    String? cn,
    String? kode,
  }) =>
      state = state.copyWith(
          start: start, end: end, egi: egi, crew: crew, cn: cn, kode: kode);
}

final ewacsFilterProvider =
    NotifierProvider<EwacsFilterNotifier, EwacsFilter>(EwacsFilterNotifier.new);

/// Dropdown filter (EGI/Crew/Unit).
final ewacsFiltersProvider = FutureProvider<EwacsFilters>((ref) async {
  try {
    return await ref.watch(ewacsApiProvider).filters();
  } catch (e) {
    throw Exception(apiMessage(e));
  }
});

/// KPI + trend + detail mengikuti filter aktif.
final ewacsKpiProvider = FutureProvider<EwacsKpi>((ref) async {
  final f = ref.watch(ewacsFilterProvider);
  return ref
      .watch(ewacsApiProvider)
      .kpi(start: f.start, end: f.end, egi: f.egi, crew: f.crew, cn: f.cn);
});

final ewacsTrendProvider = FutureProvider<List<EwacsTrend>>((ref) async {
  final f = ref.watch(ewacsFilterProvider);
  return ref
      .watch(ewacsApiProvider)
      .trend(start: f.start, end: f.end, egi: f.egi, crew: f.crew, cn: f.cn);
});

final ewacsDetailProvider = FutureProvider<List<EwacsDetail>>((ref) async {
  final f = ref.watch(ewacsFilterProvider);
  return ref.watch(ewacsApiProvider).detail(
      start: f.start,
      end: f.end,
      egi: f.egi,
      crew: f.crew,
      cn: f.cn,
      kode: f.kode,
      limit: 100);
});
