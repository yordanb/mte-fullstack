import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/network/dio_client.dart' show apiMessage;
import '../data/proker_api.dart';
import '../domain/proker_models.dart';

/// Ukuran halaman daftar unit — sama dengan web (pageSize 50).
const int prokerPageSize = 50;

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

// ─────────────────────── Proker GMC Pompa Primer ───────────────────────────

/// Filter halaman GMC Pompa Primer (web Proker.tsx: search/product/model/
/// engine + halaman).
class PrimerFilter {
  final String q;
  final String product;
  final String model;
  final String engine;
  final int page;

  const PrimerFilter({
    this.q = '',
    this.product = '',
    this.model = '',
    this.engine = '',
    this.page = 1,
  });

  PrimerFilter copyWith({
    String? q,
    String? product,
    String? model,
    String? engine,
    int? page,
  }) =>
      PrimerFilter(
        q: q ?? this.q,
        product: product ?? this.product,
        model: model ?? this.model,
        engine: engine ?? this.engine,
        page: page ?? this.page,
      );
}

class PrimerFilterNotifier extends Notifier<PrimerFilter> {
  @override
  PrimerFilter build() => const PrimerFilter();

  /// Terapkan filter terpilih — selalu kembali ke halaman 1 (web).
  void apply({
    String? q,
    String? product,
    String? model,
    String? engine,
  }) =>
      state = state.copyWith(
        q: q,
        product: product,
        model: model,
        engine: engine,
        page: 1,
      );

  void setPage(int p) => state = state.copyWith(page: p);
}

final primerFilterProvider =
    NotifierProvider<PrimerFilterNotifier, PrimerFilter>(
        PrimerFilterNotifier.new);

final primerStatsProvider = FutureProvider<ProkerStats>((ref) async {
  final api = ref.watch(prokerApiProvider);
  return _guard(ref, api.primerStats);
});

final primerFiltersProvider = FutureProvider<ProkerFilters>((ref) async {
  final api = ref.watch(prokerApiProvider);
  return _guard(ref, api.primerFilters);
});

final primerUnitsProvider = FutureProvider<ListPage<ProkerUnit>>((ref) async {
  final f = ref.watch(primerFilterProvider);
  final api = ref.watch(prokerApiProvider);
  return _guard(
    ref,
    () => api.primerUnits(
      search: f.q,
      product: f.product,
      model: f.model,
      engine: f.engine,
      page: f.page,
      pageSize: prokerPageSize,
    ),
  );
});

final primerDetailProvider =
    FutureProvider.family<ProkerDetail, String>((ref, cn) async {
  final api = ref.watch(prokerApiProvider);
  return _guard(ref, () => api.primerDetail(cn));
});

// ────────── Filter bersama Booster / Injector / Thermostat ─────────────────

/// Filter 3 varian lain: search/product/model + opsi "hanya jatuh tempo".
class ProkerUnitFilter {
  final String q;
  final String product;
  final String model;
  final bool due;
  final int page;

  const ProkerUnitFilter({
    this.q = '',
    this.product = '',
    this.model = '',
    this.due = false,
    this.page = 1,
  });

  ProkerUnitFilter copyWith({
    String? q,
    String? product,
    String? model,
    bool? due,
    int? page,
  }) =>
      ProkerUnitFilter(
        q: q ?? this.q,
        product: product ?? this.product,
        model: model ?? this.model,
        due: due ?? this.due,
        page: page ?? this.page,
      );
}

class ProkerUnitFilterNotifier extends Notifier<ProkerUnitFilter> {
  @override
  ProkerUnitFilter build() => const ProkerUnitFilter();

  void apply({String? q, String? product, String? model, bool? due}) =>
      state = state.copyWith(
        q: q,
        product: product,
        model: model,
        due: due,
        page: 1,
      );

  void setPage(int p) => state = state.copyWith(page: p);
}

final boosterFilterProvider =
    NotifierProvider<ProkerUnitFilterNotifier, ProkerUnitFilter>(
        ProkerUnitFilterNotifier.new);
final injectorFilterProvider =
    NotifierProvider<ProkerUnitFilterNotifier, ProkerUnitFilter>(
        ProkerUnitFilterNotifier.new);
final thermoFilterProvider =
    NotifierProvider<ProkerUnitFilterNotifier, ProkerUnitFilter>(
        ProkerUnitFilterNotifier.new);

// ───────────────────── Proker Midlife Eng Booster ──────────────────────────

final boosterKpiProvider = FutureProvider<BoosterKpi>((ref) async {
  final api = ref.watch(prokerApiProvider);
  return _guard(ref, api.boosterKpi);
});

final boosterFiltersProvider = FutureProvider<BoosterFilters>((ref) async {
  final api = ref.watch(prokerApiProvider);
  return _guard(ref, api.boosterFilters);
});

final boosterUnitsProvider =
    FutureProvider<ListPage<BoosterUnit>>((ref) async {
  final f = ref.watch(boosterFilterProvider);
  final api = ref.watch(prokerApiProvider);
  return _guard(
    ref,
    () => api.boosterUnits(
      search: f.q,
      product: f.product,
      model: f.model,
      due: f.due ? true : null,
      page: f.page,
      pageSize: prokerPageSize,
    ),
  );
});

final boosterDetailProvider =
    FutureProvider.family<BoosterDetail, String>((ref, cn) async {
  final api = ref.watch(prokerApiProvider);
  return _guard(ref, () => api.boosterDetail(cn));
});

// ──────────────────── Proker Midlife Injector Primer ───────────────────────

final injectorKpiProvider = FutureProvider<InjectorKpi>((ref) async {
  final api = ref.watch(prokerApiProvider);
  return _guard(ref, api.injectorKpi);
});

final injectorFiltersProvider = FutureProvider<InjectorFilters>((ref) async {
  final api = ref.watch(prokerApiProvider);
  return _guard(ref, api.injectorFilters);
});

final injectorUnitsProvider =
    FutureProvider<ListPage<InjectorUnit>>((ref) async {
  final f = ref.watch(injectorFilterProvider);
  final api = ref.watch(prokerApiProvider);
  return _guard(
    ref,
    () => api.injectorUnits(
      search: f.q,
      product: f.product,
      model: f.model,
      due: f.due ? true : null,
      page: f.page,
      pageSize: prokerPageSize,
    ),
  );
});

final injectorDetailProvider =
    FutureProvider.family<InjectorDetail, String>((ref, cn) async {
  final api = ref.watch(prokerApiProvider);
  return _guard(ref, () => api.injectorDetail(cn));
});

// ───────────────────────── Proker Thermostat CAT ───────────────────────────

final thermoKpiProvider = FutureProvider<ThermostatKpi>((ref) async {
  final api = ref.watch(prokerApiProvider);
  return _guard(ref, api.thermostatKpi);
});

final thermoFiltersProvider = FutureProvider<ThermostatFilters>((ref) async {
  final api = ref.watch(prokerApiProvider);
  return _guard(ref, api.thermostatFilters);
});

final thermoUnitsProvider =
    FutureProvider<ListPage<ThermostatUnit>>((ref) async {
  final f = ref.watch(thermoFilterProvider);
  final api = ref.watch(prokerApiProvider);
  return _guard(
    ref,
    () => api.thermostatUnits(
      search: f.q,
      product: f.product,
      model: f.model,
      due: f.due ? true : null,
      page: f.page,
      pageSize: prokerPageSize,
    ),
  );
});

// ──────────────────────── Invalidasi setelah aksi ──────────────────────────

void invalidatePrimerData(WidgetRef ref) {
  ref.invalidate(primerStatsProvider);
  ref.invalidate(primerFiltersProvider);
  ref.invalidate(primerUnitsProvider);
  ref.invalidate(primerDetailProvider);
}

void invalidateBoosterData(WidgetRef ref) {
  ref.invalidate(boosterKpiProvider);
  ref.invalidate(boosterFiltersProvider);
  ref.invalidate(boosterUnitsProvider);
  ref.invalidate(boosterDetailProvider);
}

void invalidateInjectorData(WidgetRef ref) {
  ref.invalidate(injectorKpiProvider);
  ref.invalidate(injectorFiltersProvider);
  ref.invalidate(injectorUnitsProvider);
  ref.invalidate(injectorDetailProvider);
}

void invalidateThermoData(WidgetRef ref) {
  ref.invalidate(thermoKpiProvider);
  ref.invalidate(thermoFiltersProvider);
  ref.invalidate(thermoUnitsProvider);
}
