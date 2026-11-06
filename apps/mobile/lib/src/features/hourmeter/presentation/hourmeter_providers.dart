import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;

import '../data/hourmeter_api.dart';
import '../domain/hourmeter_models.dart';

/// Periode aktif (bulan/tahun) grid HM — default bulan berjalan (web).
class HourmeterPeriodSel {
  final int year;
  final int month;
  const HourmeterPeriodSel(this.year, this.month);

  /// Kunci "YYYY-MM" seperti backend.
  String get key => '$year-${month.toString().padLeft(2, '0')}';
}

class HourmeterPeriodNotifier extends Notifier<HourmeterPeriodSel> {
  @override
  HourmeterPeriodSel build() {
    final now = DateTime.now();
    return HourmeterPeriodSel(now.year, now.month);
  }

  void setMonth(int m) => state = HourmeterPeriodSel(state.year, m);
  void setYear(int y) => state = HourmeterPeriodSel(y, state.month);
}

final hourmeterPeriodProvider =
    NotifierProvider<HourmeterPeriodNotifier, HourmeterPeriodSel>(
        HourmeterPeriodNotifier.new);

/// Grid HM periode aktif. 401 → force logout (pola sama Dashboard).
final hourmeterPivotProvider = FutureProvider<HourmeterPivot>((ref) async {
  final p = ref.watch(hourmeterPeriodProvider);
  try {
    return await ref
        .watch(hourmeterApiProvider)
        .pivot(year: p.year, month: p.month);
  } on DioException catch (e) {
    if (e.response?.statusCode == 401) {
      await ref.read(authProvider.notifier).forceLogout();
    }
    throw Exception(apiMessage(e));
  } catch (e) {
    throw Exception(apiMessage(e));
  }
});

/// Ringkasan periode + log upload (web fetchHourmeterStats).
final hourmeterStatsProvider = FutureProvider<HourmeterStats>((ref) async {
  try {
    return await ref.watch(hourmeterApiProvider).stats();
  } catch (e) {
    throw Exception(apiMessage(e));
  }
});
