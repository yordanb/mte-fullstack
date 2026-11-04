import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/proker_models.dart';

/// Lapisan data modul Proker: 4 varian endpoint
/// (/v1/proker, /v1/booster, /v1/injector, /v1/thermostat).
class ProkerApi {
  final Dio _dio;
  ProkerApi(this._dio);

  static final _opts = Options(
    sendTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  );

  /// Refresh HM memindai sumber Hourmeter & Yazu DC — timeout longgar.
  static final _optsRefresh = Options(
    sendTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 120),
  );

  Map<String, dynamic> _q({
    String? search,
    String? product,
    String? model,
    String? engine,
    bool? due,
    int? page,
    int? pageSize,
  }) =>
      {
        if (search != null && search.isNotEmpty) 'search': search,
        if (product != null && product.isNotEmpty) 'product': product,
        if (model != null && model.isNotEmpty) 'model': model,
        if (engine != null && engine.isNotEmpty) 'engine': engine,
        if (due == true) 'due': true,
        if (page != null && page > 0) 'page': page,
        if (pageSize != null && pageSize > 0) 'page_size': pageSize,
      };

  Future<Map<String, dynamic>> _get(String path, String context,
      {Map<String, dynamic>? query}) async {
    try {
      final r = await _dio.get(path, queryParameters: query, options: _opts);
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      throw _handleDioError(e, context);
    }
  }

  Future<Map<String, dynamic>> _post(String path, String context,
      {Options? options}) async {
    try {
      final r = await _dio.post(path, options: options ?? _opts);
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      throw _handleDioError(e, context);
    }
  }

  // ── Proker GMC Pompa Primer ─────────────────────────────────────
  Future<ProkerStats> primerStats() async => ProkerStats.fromJson(
      await _get('/v1/proker/stats', 'ringkasan Proker GMC'));

  Future<ProkerFilters> primerFilters() async => ProkerFilters.fromJson(
      await _get('/v1/proker/filters', 'filter Proker GMC'));

  Future<ListPage<ProkerUnit>> primerUnits({
    String? search,
    String? product,
    String? model,
    String? engine,
    int page = 1,
    int pageSize = 50,
  }) async =>
      ListPage.fromJson(
        await _get('/v1/proker/units', 'daftar unit Proker GMC',
            query: _q(
                search: search,
                product: product,
                model: model,
                engine: engine,
                page: page,
                pageSize: pageSize)),
        ProkerUnit.fromJson,
      );

  Future<ProkerDetail> primerDetail(String cn) async => ProkerDetail.fromJson(
      await _get('/v1/proker/units/${Uri.encodeComponent(cn)}',
          'riwayat proker $cn'));

  Future<RefreshHmResult> primerRefreshHm() async => RefreshHmResult.fromJson(
      await _post('/v1/proker/refresh-hm', 'refresh HM Proker GMC',
          options: _optsRefresh));

  // ── Proker Midlife Eng Booster ──────────────────────────────────
  Future<BoosterKpi> boosterKpi() async => BoosterKpi.fromJson(
      await _get('/v1/booster/stats', 'ringkasan booster'));

  Future<BoosterFilters> boosterFilters() async => BoosterFilters.fromJson(
      await _get('/v1/booster/filters', 'filter booster'));

  Future<ListPage<BoosterUnit>> boosterUnits({
    String? search,
    String? product,
    String? model,
    bool? due,
    int page = 1,
    int pageSize = 50,
  }) async =>
      ListPage.fromJson(
        await _get('/v1/booster/units', 'daftar unit booster',
            query: _q(
                search: search,
                product: product,
                model: model,
                due: due,
                page: page,
                pageSize: pageSize)),
        BoosterUnit.fromJson,
      );

  Future<BoosterDetail> boosterDetail(String cn) async => BoosterDetail.fromJson(
      await _get('/v1/booster/units/${Uri.encodeComponent(cn)}',
          'riwayat booster $cn'));

  Future<RefreshHmResult> boosterRefreshHm() async => RefreshHmResult.fromJson(
      await _post('/v1/booster/refresh-hm', 'refresh HM booster',
          options: _optsRefresh));

  // ── Proker Midlife Injector Primer ──────────────────────────────
  Future<InjectorKpi> injectorKpi() async => InjectorKpi.fromJson(
      await _get('/v1/injector/stats', 'ringkasan injector'));

  Future<InjectorFilters> injectorFilters() async => InjectorFilters.fromJson(
      await _get('/v1/injector/filters', 'filter injector'));

  Future<ListPage<InjectorUnit>> injectorUnits({
    String? search,
    String? product,
    String? model,
    bool? due,
    int page = 1,
    int pageSize = 50,
  }) async =>
      ListPage.fromJson(
        await _get('/v1/injector/units', 'daftar unit injector',
            query: _q(
                search: search,
                product: product,
                model: model,
                due: due,
                page: page,
                pageSize: pageSize)),
        InjectorUnit.fromJson,
      );

  Future<InjectorDetail> injectorDetail(String cn) async =>
      InjectorDetail.fromJson(await _get(
          '/v1/injector/units/${Uri.encodeComponent(cn)}',
          'riwayat injector $cn'));

  Future<RefreshHmResult> injectorRefreshHm() async =>
      RefreshHmResult.fromJson(await _post(
          '/v1/injector/refresh-hm', 'refresh HM injector',
          options: _optsRefresh));

  // ── Proker Thermostat CAT ───────────────────────────────────────
  Future<ThermostatKpi> thermostatKpi() async => ThermostatKpi.fromJson(
      await _get('/v1/thermostat/stats', 'ringkasan thermostat'));

  Future<ThermostatFilters> thermostatFilters() async =>
      ThermostatFilters.fromJson(
          await _get('/v1/thermostat/filters', 'filter thermostat'));

  Future<ListPage<ThermostatUnit>> thermostatUnits({
    String? search,
    String? product,
    String? model,
    bool? due,
    int page = 1,
    int pageSize = 50,
  }) async =>
      ListPage.fromJson(
        await _get('/v1/thermostat/units', 'daftar unit thermostat',
            query: _q(
                search: search,
                product: product,
                model: model,
                due: due,
                page: page,
                pageSize: pageSize)),
        ThermostatUnit.fromJson,
      );

  Future<RefreshHmResult> thermostatRefreshHm() async =>
      RefreshHmResult.fromJson(await _post(
          '/v1/thermostat/refresh-hm', 'refresh HM thermostat',
          options: _optsRefresh));

  Exception _handleDioError(DioException e, String context) {
    if (kIsWeb && e.type == DioExceptionType.connectionError) {
      return Exception(
          'Error jaringan saat mengambil $context. Periksa akses API/CORS.');
    }
    if (e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionTimeout) {
      return Exception('Timeout saat mengambil $context. API tidak merespons.');
    }
    return Exception('Gagal mengambil $context: ${ApiException.fromDio(e).message}');
  }
}

final prokerApiProvider = Provider<ProkerApi>((ref) => ProkerApi(ref.watch(dioProvider)));
