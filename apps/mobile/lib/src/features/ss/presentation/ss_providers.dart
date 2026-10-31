import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/network/dio_client.dart' show apiMessage;
import '../../../core/utils/date_fmt.dart';
import '../data/ss_api.dart';
import '../domain/ss_models.dart';

/// Filter Suggestion System, meniru default web Ss.tsx:
/// basis tanggal "menilai", rentang awal bulan berjalan s/d hari ini.
class SsFilterNotifier extends Notifier<SsParams> {
  @override
  SsParams build() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return SsParams(
      dateBasis: 'menilai',
      start: toApiDate(monthStart),
      end: toApiDate(now),
    );
  }

  void apply({
    String? dateBasis,
    String? start,
    String? end,
    String? dept,
    String? kategori,
    String? grade,
    String? status,
    String? tahap,
    String? search,
  }) {
    state = SsParams(
      dateBasis: dateBasis ?? state.dateBasis,
      start: start ?? state.start,
      end: end ?? state.end,
      dept: dept ?? state.dept,
      kategori: kategori ?? state.kategori,
      grade: grade ?? state.grade,
      status: status ?? state.status,
      tahap: tahap ?? state.tahap,
      search: search ?? state.search,
      granularity: state.granularity,
    );
  }

  void reset() {
    final now = DateTime.now();
    state = SsParams(
      dateBasis: 'menilai',
      start: toApiDate(DateTime(now.year, now.month, 1)),
      end: toApiDate(now),
    );
  }
}

final ssFilterProvider =
    NotifierProvider<SsFilterNotifier, SsParams>(SsFilterNotifier.new);

/// Bungkus pemanggilan API: 401 -> paksa logout, error lain -> pesan rapi.
Future<T> _guard<T>(Ref ref, Future<T> Function() run) async {
  try {
    return await run();
  } on DioException catch (e) {
    if (e.response?.statusCode == 401) {
      await ref.read(authProvider.notifier).forceLogout();
    }
    throw apiMessage(e);
  } catch (e) {
    throw apiMessage(e);
  }
}

final ssKpiProvider = FutureProvider<SsKpi>((ref) async {
  final p = ref.watch(ssFilterProvider);
  final api = ref.watch(ssApiProvider);
  return _guard(ref, () => api.kpi(p));
});

final ssTargetCrewProvider = FutureProvider<SsTargetCrewResp>((ref) async {
  final p = ref.watch(ssFilterProvider);
  final api = ref.watch(ssApiProvider);
  return _guard(ref, () => api.targetCrew(p));
});

/// Jumlah SS per tanggal laporan (satu batang per hari).
final ssDailyTrendProvider = FutureProvider<List<SsTrendPoint>>((ref) async {
  final p = ref.watch(ssFilterProvider).copyWith(granularity: 'day');
  final api = ref.watch(ssApiProvider);
  return _guard(ref, () => api.trend(p));
});

/// Jumlah SS per bulan (bucket "bulan").
final ssMonthlyTrendProvider = FutureProvider<List<SsTrendPoint>>((ref) async {
  final p = ref.watch(ssFilterProvider).copyWith(granularity: 'month');
  final api = ref.watch(ssApiProvider);
  return _guard(ref, () => api.trend(p));
});

final ssRecordsProvider = FutureProvider<List<SsRecord>>((ref) async {
  final p = ref.watch(ssFilterProvider);
  final api = ref.watch(ssApiProvider);
  return _guard(ref, () => api.records(p, pageSize: 50));
});
