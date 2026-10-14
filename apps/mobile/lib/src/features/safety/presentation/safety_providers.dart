import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;

import '../data/safety_api.dart';
import '../domain/safety_models.dart';

enum SafetyMode { bomak, r1bi }

class SafetyModeNotifier extends Notifier<SafetyMode> {
  @override
  SafetyMode build() => SafetyMode.bomak;
  void set(SafetyMode m) => state = m;
}

final safetyModeProvider =
    NotifierProvider<SafetyModeNotifier, SafetyMode>(SafetyModeNotifier.new);

/// Filter Safety: bulan berjalan + section + risiko (R1BI) + cari + halaman.
/// Web: Tampilkan = cov+rows, Cari = rows saja (page 1).
class SafetyFilter {
  final int year;
  final int month;
  final String sec;
  final String risk;
  final String q;
  final int page;

  const SafetyFilter({
    required this.year,
    required this.month,
    this.sec = '',
    this.risk = '',
    this.q = '',
    this.page = 1,
  });

  SafetyFilter copyWith({
    int? year,
    int? month,
    String? sec,
    String? risk,
    String? q,
    int? page,
  }) =>
      SafetyFilter(
        year: year ?? this.year,
        month: month ?? this.month,
        sec: sec ?? this.sec,
        risk: risk ?? this.risk,
        q: q ?? this.q,
        page: page ?? this.page,
      );
}

class SafetyFilterNotifier extends Notifier<SafetyFilter> {
  @override
  SafetyFilter build() {
    final now = DateTime.now();
    return SafetyFilter(year: now.year, month: now.month);
  }

  void shiftMonth(int n) {
    final d = DateTime(state.year, state.month + n, 1);
    state = state.copyWith(year: d.year, month: d.month, page: 1);
  }

  void apply({String? sec, String? risk, String? q}) {
    state = state.copyWith(sec: sec, risk: risk, q: q, page: 1);
  }

  void setPage(int p) => state = state.copyWith(page: p);
}

final safetyFilterProvider =
    NotifierProvider<SafetyFilterNotifier, SafetyFilter>(SafetyFilterNotifier.new);

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

// ---- Bomak ----
final bomakCoverageProvider = FutureProvider<
    ({List<SafetyCoverageRow> coverage, SafetyCompliance compliance, List<String> sections})>(
    (ref) async {
  final f = ref.watch(safetyFilterProvider);
  return _guard(ref, () => ref.watch(safetyApiProvider).coverage(f.year, f.month));
});

final bomakRowsProvider = FutureProvider<({int total, int page, List<SafetyRow> rows})>(
    (ref) async {
  final f = ref.watch(safetyFilterProvider);
  return _guard(
    ref,
    () => ref.watch(safetyApiProvider).records(
          dateFrom: monthStart(f.year, f.month),
          dateTo: monthEnd(f.year, f.month),
          section: f.sec.isEmpty ? null : f.sec,
          search: f.q.isEmpty ? null : f.q,
          page: f.page,
        ),
  );
});

final bomakSyncProvider = FutureProvider<LatestSync?>((ref) async {
  try {
    return await ref.watch(safetyApiProvider).latestSync();
  } catch (_) {
    return null;
  }
});

// ---- R1BI ----
final ribiCoverageProvider = FutureProvider<
    ({List<RibiCoverageRow> coverage, int total, int high, List<String> sections})>(
    (ref) async {
  final f = ref.watch(safetyFilterProvider);
  return _guard(
      ref, () => ref.watch(safetyApiProvider).ribiCoverage(f.year, f.month));
});

final ribiRowsProvider = FutureProvider<({int total, int page, List<RibiRow> rows})>(
    (ref) async {
  final f = ref.watch(safetyFilterProvider);
  return _guard(
    ref,
    () => ref.watch(safetyApiProvider).ribiRecords(
          dateFrom: monthStart(f.year, f.month),
          dateTo: monthEnd(f.year, f.month),
          section: f.sec.isEmpty ? null : f.sec,
          risk: f.risk.isEmpty ? null : f.risk,
          search: f.q.isEmpty ? null : f.q,
          page: f.page,
        ),
  );
});

final ribiSyncProvider = FutureProvider<LatestSync?>((ref) async {
  try {
    return await ref.watch(safetyApiProvider).ribiLatestSync();
  } catch (_) {
    return null;
  }
});

const List<String> idMonthNames = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
];

String monthTitle(int year, int month) => '${idMonthNames[month - 1]} $year';

void invalidateSafety(WidgetRef ref) {
  ref.invalidate(bomakCoverageProvider);
  ref.invalidate(bomakRowsProvider);
  ref.invalidate(bomakSyncProvider);
  ref.invalidate(ribiCoverageProvider);
  ref.invalidate(ribiRowsProvider);
  ref.invalidate(ribiSyncProvider);
}
