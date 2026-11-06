import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;

import '../data/yazu_api.dart';
import '../domain/yazu_models.dart';

/// Periode aktif (bulan/tahun) pivot Yazu.
class YazuMonth {
  final int year;
  final int month;
  const YazuMonth(this.year, this.month);
}

class YazuMonthNotifier extends Notifier<YazuMonth> {
  @override
  YazuMonth build() {
    final now = DateTime.now();
    return YazuMonth(now.year, now.month);
  }

  void setMonth(int m) => state = YazuMonth(state.year, m);
  void setYear(int y) => state = YazuMonth(y, state.month);
}

/// Periode Yazu P2H & Yazu Daily Check dipisah agar tak saling mengganggu.
final yazuMonthProvider =
    NotifierProvider<YazuMonthNotifier, YazuMonth>(YazuMonthNotifier.new);
final yazuDcMonthProvider =
    NotifierProvider<YazuMonthNotifier, YazuMonth>(YazuMonthNotifier.new);

/// Pivot & stats Yazu P2H.
final yazuPivotProvider = FutureProvider<YazuPivot>((ref) async {
  final p = ref.watch(yazuMonthProvider);
  final r = await ref
      .watch(yazuApiProvider)
      .pivot(year: p.year, month: p.month);
  return r;
});

final yazuStatsProvider = FutureProvider<YazuStats>((ref) async {
  return ref.watch(yazuApiProvider).stats();
});

/// Pivot & stats Yazu Daily Check.
final yazuDcPivotProvider = FutureProvider<YazuPivot>((ref) async {
  final p = ref.watch(yazuDcMonthProvider);
  return ref.watch(yazuDcApiProvider).pivot(year: p.year, month: p.month);
});

final yazuDcStatsProvider = FutureProvider<YazuStats>((ref) async {
  return ref.watch(yazuDcApiProvider).stats();
});

/// Map DioException → pesan server (untuk UI).
String yazuErr(Object e) => apiMessage(e);
