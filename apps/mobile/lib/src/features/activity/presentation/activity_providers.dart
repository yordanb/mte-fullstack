import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;
import 'package:mte_data_center/src/core/utils/date_fmt.dart';

import '../data/activity_api.dart';
import '../domain/activity_models.dart';

/// Bulan kalender aktif.
class ActivityMonth {
  final int year;
  final int month;
  const ActivityMonth(this.year, this.month);
}

class ActivityMonthNotifier extends Notifier<ActivityMonth> {
  @override
  ActivityMonth build() {
    final now = DateTime.now();
    return ActivityMonth(now.year, now.month);
  }

  void shift(int n) {
    final d = DateTime(state.year, state.month + n, 1);
    state = ActivityMonth(d.year, d.month);
  }

  void jump(int year, int month) => state = ActivityMonth(year, month);
}

final activityMonthProvider =
    NotifierProvider<ActivityMonthNotifier, ActivityMonth>(ActivityMonthNotifier.new);

/// Tanggal terpilih (YYYY-MM-DD lokal). Default hari ini seperti web todayLocal().
class SelectedDateNotifier extends Notifier<String> {
  @override
  String build() => toApiDate(DateTime.now());
  void select(String d) => state = d;
}

final selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, String>(SelectedDateNotifier.new);

/// Filter crew/kategori (server-side ILIKE, seperti web applyFilter).
class ActivityFilter {
  final String crew;
  final String category;
  const ActivityFilter({this.crew = '', this.category = ''});
}

class ActivityFilterNotifier extends Notifier<ActivityFilter> {
  @override
  ActivityFilter build() => const ActivityFilter();
  void setCrew(String v) => state = ActivityFilter(crew: v, category: state.category);
  void setCategory(String v) => state = ActivityFilter(crew: state.crew, category: v);
}

final activityFilterProvider =
    NotifierProvider<ActivityFilterNotifier, ActivityFilter>(ActivityFilterNotifier.new);

/// Token akses: pindah ke core (token_storage.accessTokenProvider).

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

final monthCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final ym = ref.watch(activityMonthProvider);
  final f = ref.watch(activityFilterProvider);
  final api = ref.watch(activityApiProvider);
  return _guard(ref, () => api.monthCounts(
        year: ym.year,
        month: ym.month,
        crew: f.crew.isEmpty ? null : f.crew,
        category: f.category.isEmpty ? null : f.category,
      ));
});

/// List harian + filter client-side (meniru web match()).
final dayItemsProvider = FutureProvider<List<Activity>>((ref) async {
  final date = ref.watch(selectedDateProvider);
  final f = ref.watch(activityFilterProvider);
  final api = ref.watch(activityApiProvider);
  final items = await _guard(ref, () => api.byDate(date));
  return items.where((a) {
    final okCrew = f.crew.isEmpty ||
        (a.crew ?? '').toLowerCase().contains(f.crew.toLowerCase());
    final okCat = f.category.isEmpty ||
        (a.category ?? '').toLowerCase().contains(f.category.toLowerCase());
    return okCrew && okCat;
  }).toList();
});

final recapProvider = FutureProvider<List<Activity>>((ref) async {
  final ym = ref.watch(activityMonthProvider);
  final f = ref.watch(activityFilterProvider);
  final api = ref.watch(activityApiProvider);
  return _guard(ref, () => api.recap(
        year: ym.year,
        month: ym.month,
        crew: f.crew.isEmpty ? null : f.crew,
        category: f.category.isEmpty ? null : f.category,
      ));
});

final activityDetailProvider = FutureProvider.family<Activity, String>((ref, id) async {
  final api = ref.watch(activityApiProvider);
  return _guard(ref, () => api.detail(id));
});

/// Panggil setelah simpan/hapus agar kalender + rekap + list segar.
void invalidateActivityLists(WidgetRef ref) {
  ref.invalidate(monthCountsProvider);
  ref.invalidate(dayItemsProvider);
  ref.invalidate(recapProvider);
}
