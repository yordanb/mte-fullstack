import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_api.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/network/dio_client.dart' show apiMessage;

/// Filter dashboard meniru Pages.tsx: mode latest/search + radio Critical TL/GS/WP.
class DashboardFilter {
  final String vessel;
  final String unit;
  final String mode; // 'latest' | 'search'
  final String critPrefix; // '' | TL | GS | WP

  const DashboardFilter({
    this.vessel = '',
    this.unit = '',
    this.mode = 'latest',
    this.critPrefix = '',
  });

  DashboardFilter copyWith({String? vessel, String? unit, String? mode, String? critPrefix}) =>
      DashboardFilter(
        vessel: vessel ?? this.vessel,
        unit: unit ?? this.unit,
        mode: mode ?? this.mode,
        critPrefix: critPrefix ?? this.critPrefix,
      );
}

class DashboardFilterNotifier extends Notifier<DashboardFilter> {
  @override
  DashboardFilter build() => const DashboardFilter();

  void setVessel(String v) => state = state.copyWith(vessel: v.toUpperCase());
  void setUnit(String v) => state = state.copyWith(unit: v.toUpperCase());

  void reset() => state = const DashboardFilter();

  void applyCritical(String prefix) =>
      state = state.copyWith(mode: 'latest', critPrefix: prefix, vessel: '', unit: '');

  void applySearch() => state = state.copyWith(mode: 'search', critPrefix: '');
}

final dashboardFilterProvider =
    NotifierProvider<DashboardFilterNotifier, DashboardFilter>(DashboardFilterNotifier.new);

class DashboardRows {
  final List<LabRow> rows;
  final String? error;
  const DashboardRows({this.rows = const [], this.error});
}

/// Rows mengikuti filter aktif. 401 final -> paksa logout (ke /login).
final dashboardRowsProvider = FutureProvider<DashboardRows>((ref) async {
  final f = ref.watch(dashboardFilterProvider);
  final api = ref.watch(dashboardApiProvider);
  try {
    if (f.mode == 'search') {
      return DashboardRows(rows: await api.search(f.vessel, f.unit.isEmpty ? null : f.unit));
    }
    if (f.critPrefix.isNotEmpty) {
      return DashboardRows(
          rows: await api.latestPerUnit(limit: 200, prefix: f.critPrefix, condition: 'CRITICAL'));
    }
    return DashboardRows(rows: await api.latestPerUnit(limit: 200));
  } on DioException catch (e) {
    if (e.response?.statusCode == 401) {
      await ref.read(authProvider.notifier).forceLogout();
    }
    return DashboardRows(error: apiMessage(e));
  } catch (e) {
    return DashboardRows(error: apiMessage(e));
  }
});

final lastImportProvider = FutureProvider<ImportStatus?>((ref) async {
  try {
    return await ref.watch(dashboardApiProvider).latestImport();
  } catch (_) {
    return null;
  }
});
