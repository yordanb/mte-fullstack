import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;

import '../data/manpower_api.dart';
import '../domain/manpower_models.dart';

// ── Manpower Inovasi ──────────────────────────────────────────────

/// Periode terpilih (default: periode pertama dari /periods).
final manpowerPeriodeProvider = NotifierProvider<ManpowerPeriodeNotifier, String>(
    ManpowerPeriodeNotifier.new);

class ManpowerPeriodeNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String p) => state = p;
}

/// Dept terpilih ('' = semua).
final manpowerDeptProvider = NotifierProvider<ManpowerDeptNotifier, String>(
    ManpowerDeptNotifier.new);

class ManpowerDeptNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String d) => state = d;
}

/// Filter tabel data manpower.
class ManpowerRecordsFilter {
  final String search;
  final bool innovatorOnly;
  final int pageSize;
  final int page;
  final String sort;
  final String dir;
  const ManpowerRecordsFilter({
    this.search = '',
    this.innovatorOnly = false,
    this.pageSize = 25,
    this.page = 1,
    this.sort = 'nama',
    this.dir = 'asc',
  });

  ManpowerRecordsFilter copyWith({
    String? search,
    bool? innovatorOnly,
    int? pageSize,
    int? page,
    String? sort,
    String? dir,
  }) =>
      ManpowerRecordsFilter(
        search: search ?? this.search,
        innovatorOnly: innovatorOnly ?? this.innovatorOnly,
        pageSize: pageSize ?? this.pageSize,
        page: page ?? this.page,
        sort: sort ?? this.sort,
        dir: dir ?? this.dir,
      );
}

class ManpowerRecordsFilterNotifier
    extends Notifier<ManpowerRecordsFilter> {
  @override
  ManpowerRecordsFilter build() => const ManpowerRecordsFilter();

  void setSearch(String s) => state = state.copyWith(search: s, page: 1);
  void setInnovatorOnly(bool v) =>
      state = state.copyWith(innovatorOnly: v, page: 1);
  void setPageSize(int n) => state = state.copyWith(pageSize: n, page: 1);
  void setPage(int p) => state = state.copyWith(page: p);

  /// Urutkan seperti web sortBy.
  void sortBy(String key) {
    if (state.sort == key) {
      state = state.copyWith(dir: state.dir == 'desc' ? 'asc' : 'desc', page: 1);
    } else {
      final asc = key == 'nama' || key == 'nrp';
      state = state.copyWith(sort: key, dir: asc ? 'asc' : 'desc', page: 1);
    }
  }
}

final manpowerRecordsFilterProvider =
    NotifierProvider<ManpowerRecordsFilterNotifier, ManpowerRecordsFilter>(
        ManpowerRecordsFilterNotifier.new);

/// Daftar periode (untuk pemilih bulan).
final manpowerPeriodsProvider = FutureProvider<List<ManpowerPeriod>>((ref) async {
  try {
    return await ref.watch(manpowerApiProvider).periods();
  } catch (e) {
    throw Exception(apiMessage(e));
  }
});

/// Ringkasan periode terpilih.
final manpowerSummaryProvider = FutureProvider<ManpowerSummary?>((ref) async {
  final periode = ref.watch(manpowerPeriodeProvider);
  final dept = ref.watch(manpowerDeptProvider);
  if (periode.isEmpty) return null;
  try {
    return await ref.watch(manpowerApiProvider).summary(periode: periode, dept: dept);
  } catch (e) {
    throw Exception(apiMessage(e));
  }
});

/// Tren per bulan.
final manpowerTrendProvider = FutureProvider<List<ManpowerPeriod>>((ref) async {
  final dept = ref.watch(manpowerDeptProvider);
  try {
    return await ref.watch(manpowerApiProvider).trend(dept: dept);
  } catch (_) {
    return <ManpowerPeriod>[];
  }
});

/// Data tabel manpower.
final manpowerRecordsProvider =
    FutureProvider<ManpowerRecordPage>((ref) async {
  final periode = ref.watch(manpowerPeriodeProvider);
  final dept = ref.watch(manpowerDeptProvider);
  final f = ref.watch(manpowerRecordsFilterProvider);
  if (periode.isEmpty) {
    return const ManpowerRecordPage();
  }
  try {
    return await ref.watch(manpowerApiProvider).records(
          periode: periode,
          dept: dept,
          search: f.search,
          innovator: f.innovatorOnly ? true : null,
          page: f.page,
          pageSize: f.pageSize,
          sort: f.sort,
          dir: f.dir,
        );
  } catch (e) {
    throw Exception(apiMessage(e));
  }
});

// ── Pengelompokan (ManpowerGroup) ─────────────────────────────────

/// Filter dashboard pengelompokan.
class ManpowerManageFilter {
  final String periode;
  final String dept;
  final String section;
  final String crew;
  final String status;
  /// Drill-down dari kartu "Rincian per Section/Crew": label kartu diklik →
  /// tabel "Data Manpower" difilter kelompok itu (label hasil derivasi kartu,
  /// bukan nilai kolom — backend cocokkan persis CASE di breakdown).
  final String sectionLabel;
  final String crewLabel;
  final String search;
  final int page;
  final int pageSize;
  final String sort;
  final String dir;
  const ManpowerManageFilter({
    this.periode = '',
    this.dept = '',
    this.section = '',
    this.crew = '',
    this.status = '',
    this.sectionLabel = '',
    this.crewLabel = '',
    this.search = '',
    this.page = 1,
    this.pageSize = 25,
    this.sort = 'nama',
    this.dir = 'asc',
  });

  ManpowerManageFilter copyWith({
    String? periode,
    String? dept,
    String? section,
    String? crew,
    String? status,
    String? sectionLabel,
    String? crewLabel,
    String? search,
    int? page,
    int? pageSize,
    String? sort,
    String? dir,
  }) =>
      ManpowerManageFilter(
        periode: periode ?? this.periode,
        dept: dept ?? this.dept,
        section: section ?? this.section,
        crew: crew ?? this.crew,
        status: status ?? this.status,
        sectionLabel: sectionLabel ?? this.sectionLabel,
        crewLabel: crewLabel ?? this.crewLabel,
        search: search ?? this.search,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        sort: sort ?? this.sort,
        dir: dir ?? this.dir,
      );

  /// Apakah ada filter aktif (untuk menampilkan tombol Reset).
  bool get hasFilter =>
      dept.isNotEmpty ||
      section.isNotEmpty ||
      crew.isNotEmpty ||
      status.isNotEmpty ||
      sectionLabel.isNotEmpty ||
      crewLabel.isNotEmpty ||
      search.isNotEmpty;
}

class ManpowerManageFilterNotifier extends Notifier<ManpowerManageFilter> {
  @override
  ManpowerManageFilter build() => const ManpowerManageFilter();

  void setPeriode(String v) => state = state.copyWith(periode: v, page: 1);
  void setDept(String v) => state = state.copyWith(dept: v, page: 1);
  void setSection(String v) => state = state.copyWith(section: v, page: 1);
  void setCrew(String v) => state = state.copyWith(crew: v, page: 1);
  void setStatus(String v) => state = state.copyWith(status: v, page: 1);
  void setSearch(String v) => state = state.copyWith(search: v, page: 1);
  void setPage(int p) => state = state.copyWith(page: p < 1 ? 1 : p);
  void setPageSize(int n) => state = state.copyWith(pageSize: n, page: 1);

  /// Klik label di kartu "Rincian per Section" → filter tabel ke label itu;
  /// klik label yang sudah aktif = batalkan (tampil semua). Select Section
  /// manual dibersihkan agar tak bentrok dengan drill-down label.
  void setSectionPick(String label) => state = state.copyWith(
        sectionLabel: state.sectionLabel == label ? '' : label,
        section: '',
        page: 1,
      );

  /// Klik label di kartu "Rincian per Crew", mirip [setSectionPick].
  void setCrewPick(String label) => state = state.copyWith(
        crewLabel: state.crewLabel == label ? '' : label,
        crew: '',
        page: 1,
      );

  void reset() => state = ManpowerManageFilter(periode: state.periode);

  void sortBy(String key) {
    if (state.sort == key) {
      state = state.copyWith(dir: state.dir == 'desc' ? 'asc' : 'desc', page: 1);
    } else {
      final asc = const ['nama', 'nrp', 'section', 'crew', 'status'].contains(key);
      state = state.copyWith(sort: key, dir: asc ? 'asc' : 'desc', page: 1);
    }
  }
}

final manpowerManageFilterProvider =
    NotifierProvider<ManpowerManageFilterNotifier, ManpowerManageFilter>(
        ManpowerManageFilterNotifier.new);

/// Penanda refresh (increment untuk reload dashboard).
final manpowerManageTickProvider =
    NotifierProvider<ManpowerManageTickNotifier, int>(
        ManpowerManageTickNotifier.new);

class ManpowerManageTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

/// Dashboard pengelompokan.
final manpowerManageProvider =
    FutureProvider<ManpowerManage>((ref) async {
  final f = ref.watch(manpowerManageFilterProvider);
  ref.watch(manpowerManageTickProvider);
  try {
    return await ref.watch(manpowerApiProvider).manage(
          periode: f.periode.isEmpty ? null : f.periode,
          dept: f.dept,
          section: f.section,
          crew: f.crew,
          status: f.status,
          sectionLabel: f.sectionLabel.isEmpty ? null : f.sectionLabel,
          crewLabel: f.crewLabel.isEmpty ? null : f.crewLabel,
          search: f.search,
          page: f.page,
          pageSize: f.pageSize,
          sort: f.sort,
          dir: f.dir,
        );
  } catch (e) {
    throw Exception(apiMessage(e));
  }
});
