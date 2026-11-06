import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;

import '../data/staging_api.dart';
import '../domain/staging_models.dart';

/// Periode terpilih (default bulan berjalan).
final stagingPeriodProvider = NotifierProvider<StagingPeriodNotifier, String>(
    StagingPeriodNotifier.new);

class StagingPeriodNotifier extends Notifier<String> {
  @override
  String build() => stagingCurPeriod();

  void set(String p) => state = p;
  void shift(int delta) => state = stagingShiftPeriod(state, delta);
}

/// Daftar grup untuk periode terpilih.
final stagingGroupsProvider =
    FutureProvider<List<StagingGroup>>((ref) async {
  final period = ref.watch(stagingPeriodProvider);
  ref.watch(stagingTickProvider);
  try {
    return await ref.watch(stagingApiProvider).groups(period);
  } catch (e) {
    throw Exception(apiMessage(e));
  }
});

/// Penanda refresh (increment untuk reload daftar grup).
final stagingTickProvider = NotifierProvider<StagingTickNotifier, int>(
    StagingTickNotifier.new);

class StagingTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

/// Riwayat perubahan periode terpilih.
final stagingChangesProvider =
    FutureProvider<List<StagingChange>>((ref) async {
  final period = ref.watch(stagingPeriodProvider);
  try {
    return await ref.watch(stagingApiProvider).changes(period);
  } catch (_) {
    return <StagingChange>[];
  }
});
