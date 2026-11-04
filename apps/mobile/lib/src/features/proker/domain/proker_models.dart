// Model modul Proker (4 halaman) — kontrak apps/web/src/api/client.ts:1402-2040
// dan apps/api/app/api/v1/{proker,booster,injector,thermostat}.py.
// Semua fromJson dibuat toleran terhadap field kosong/hilang.

double? _d(Object? v) => (v as num?)?.toDouble();
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
int? _iOrNull(Object? v) => (v as num?)?.toInt();

String? _s(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

List<String> _sList(Object? v) =>
    (v as List?)?.map((e) => '$e').toList(growable: false) ?? const <String>[];

List<Map<String, dynamic>> _mapList(Object? v) => [
      for (final e in (v as List? ?? const []))
        Map<String, dynamic>.from(e as Map),
    ];

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

/// Balasan POST /refresh-hm (semua varian Proker): updated/unchanged/not_found.
class RefreshHmResult {
  final int updated;
  final int unchanged;
  final int notFound;
  final List<RefreshHmDetail> details;

  const RefreshHmResult({
    required this.updated,
    required this.unchanged,
    required this.notFound,
    this.details = const [],
  });

  factory RefreshHmResult.fromJson(Map<String, dynamic> j) => RefreshHmResult(
        updated: _i(j['updated']),
        unchanged: _i(j['unchanged']),
        notFound: _i(j['not_found']),
        details: [
          for (final d in _mapList(j['details'])) RefreshHmDetail.fromJson(d),
        ],
      );
}

class RefreshHmDetail {
  final String cn;
  final double? before;
  final double? hmNow;
  final String source;
  final bool changed;

  const RefreshHmDetail({
    required this.cn,
    this.before,
    this.hmNow,
    this.source = '',
    this.changed = false,
  });

  factory RefreshHmDetail.fromJson(Map<String, dynamic> j) => RefreshHmDetail(
        cn: '${j['cn'] ?? ''}',
        before: _d(j['before']),
        hmNow: _d(j['hm_now']),
        source: '${j['source'] ?? ''}',
        changed: j['changed'] == true,
      );
}

/// Halaman berpaginasi generik untuk units proker/booster/injector/thermostat.
class ListPage<T> {
  final int total;
  final int page;
  final int pageSize;
  final List<T> data;

  const ListPage({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.data,
  });

  factory ListPage.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) item,
  ) =>
      ListPage(
        total: _i(j['total']),
        page: (j['page'] as num?)?.toInt() ?? 1,
        pageSize: _i(j['page_size']),
        data: [for (final e in _mapList(j['data'])) item(e)],
      );
}

// ───────────────────────── Proker GMC Pompa Primer ─────────────────────────

/// Unit baris daftar Proker (GET /v1/proker/units) sekaligus unit pada detail.
class ProkerUnit {
  final String cn;
  final int? no;
  final String? unitModel;
  final String? product;
  final String? unitType;
  final String? engineMerk;
  final String? engineModel;
  final double? hmNow;
  final int execCount;
  final int doneCount;
  final String? lastDate;
  final double? lastHm;

  const ProkerUnit({
    required this.cn,
    this.no,
    this.unitModel,
    this.product,
    this.unitType,
    this.engineMerk,
    this.engineModel,
    this.hmNow,
    this.execCount = 0,
    this.doneCount = 0,
    this.lastDate,
    this.lastHm,
  });

  factory ProkerUnit.fromJson(Map<String, dynamic> j) => ProkerUnit(
        cn: '${j['cn'] ?? ''}',
        no: _iOrNull(j['no']),
        unitModel: _s(j['unit_model']),
        product: _s(j['product']),
        unitType: _s(j['unit_type']),
        engineMerk: _s(j['engine_merk']),
        engineModel: _s(j['engine_model']),
        hmNow: _d(j['hm_now']),
        execCount: _i(j['exec_count']),
        doneCount: _i(j['done_count']),
        lastDate: _s(j['last_date']),
        lastHm: _d(j['last_hm']),
      );

  /// Judul singkat model — dipakai di kartu daftar unit.
  String get modelLabel => unitModel ?? '-';

  /// Baris kecil "product · unit_type".
  String get productTypeLabel {
    final p = product ?? '';
    final t = unitType ?? '';
    if (p.isNotEmpty && t.isNotEmpty) return '$p · $t';
    return p.isEmpty ? t : p;
  }
}

class ProkerExecution {
  final int id;
  final String cn;
  final String period;
  final int? periodYear;
  final int? periodSeq;
  final double? hm;
  final String? serviceDate;
  final String? mekanik;
  final String status;

  const ProkerExecution({
    required this.id,
    this.cn = '',
    this.period = '',
    this.periodYear,
    this.periodSeq,
    this.hm,
    this.serviceDate,
    this.mekanik,
    this.status = 'DONE',
  });

  factory ProkerExecution.fromJson(Map<String, dynamic> j) => ProkerExecution(
        id: _i(j['id']),
        cn: '${j['cn'] ?? ''}',
        period: '${j['period'] ?? ''}',
        periodYear: _iOrNull(j['period_year']),
        periodSeq: _iOrNull(j['period_seq']),
        hm: _d(j['hm']),
        serviceDate: _s(j['service_date']),
        mekanik: _s(j['mekanik']),
        status: '${j['status'] ?? 'DONE'}'.toUpperCase(),
      );
}

class ProkerDetailStats {
  final int total;
  final int done;
  final int plan;
  final int missed;
  final String? lastDate;
  final double? lastHm;
  final double interval;
  final double? dueHm;
  final double? sisaHm;

  const ProkerDetailStats({
    this.total = 0,
    this.done = 0,
    this.plan = 0,
    this.missed = 0,
    this.lastDate,
    this.lastHm,
    this.interval = 2000,
    this.dueHm,
    this.sisaHm,
  });

  factory ProkerDetailStats.fromJson(Map<String, dynamic> j) =>
      ProkerDetailStats(
        total: _i(j['total']),
        done: _i(j['done']),
        plan: _i(j['plan']),
        missed: _i(j['missed']),
        lastDate: _s(j['last_date']),
        lastHm: _d(j['last_hm']),
        interval: _d(j['interval']) ?? 2000,
        dueHm: _d(j['due_hm']),
        sisaHm: _d(j['sisa_hm']),
      );
}

class ProkerDetail {
  final ProkerUnit unit;
  final List<ProkerExecution> executions;
  final ProkerDetailStats stats;

  const ProkerDetail({
    required this.unit,
    this.executions = const [],
    this.stats = const ProkerDetailStats(),
  });

  factory ProkerDetail.fromJson(Map<String, dynamic> j) => ProkerDetail(
        unit: ProkerUnit.fromJson(_map(j['unit'])),
        executions: [
          for (final e in _mapList(j['executions']))
            ProkerExecution.fromJson(e),
        ],
        stats: ProkerDetailStats.fromJson(_map(j['stats'])),
      );
}

class ProkerStats {
  final int units;
  final int total;
  final int done;
  final int plan;
  final int late;
  final int missed;
  final int unitDone;
  final String? lastDate;
  final int thisYear;
  final int year;
  final List<ProkerPerYear> perYear;

  const ProkerStats({
    this.units = 0,
    this.total = 0,
    this.done = 0,
    this.plan = 0,
    this.late = 0,
    this.missed = 0,
    this.unitDone = 0,
    this.lastDate,
    this.thisYear = 0,
    this.year = 0,
    this.perYear = const [],
  });

  factory ProkerStats.fromJson(Map<String, dynamic> j) => ProkerStats(
        units: _i(j['units']),
        total: _i(j['total']),
        done: _i(j['done']),
        plan: _i(j['plan']),
        late: _i(j['late']),
        missed: _i(j['missed']),
        unitDone: _i(j['unit_done']),
        lastDate: _s(j['last_date']),
        thisYear: _i(j['this_year']),
        year: _i(j['year']),
        perYear: [
          for (final e in _mapList(j['per_year'])) ProkerPerYear.fromJson(e),
        ],
      );
}

class ProkerPerYear {
  final int year;
  final int total;
  final int done;

  const ProkerPerYear({this.year = 0, this.total = 0, this.done = 0});

  factory ProkerPerYear.fromJson(Map<String, dynamic> j) => ProkerPerYear(
        year: _i(j['year']),
        total: _i(j['total']),
        done: _i(j['done']),
      );
}

class ProkerFilters {
  final List<String> product;
  final List<String> model;
  final List<String> type;
  final List<String> engine;
  final List<int> years;
  final String? minDate;
  final String? maxDate;
  final int? minYear;
  final int? maxYear;

  const ProkerFilters({
    this.product = const [],
    this.model = const [],
    this.type = const [],
    this.engine = const [],
    this.years = const [],
    this.minDate,
    this.maxDate,
    this.minYear,
    this.maxYear,
  });

  factory ProkerFilters.fromJson(Map<String, dynamic> j) => ProkerFilters(
        product: _sList(j['product']),
        model: _sList(j['model']),
        type: _sList(j['type']),
        engine: _sList(j['engine']),
        years: [
          for (final y in (j['years'] as List? ?? const []))
            if ((y as num?) != null) y!.toInt(),
        ],
        minDate: _s(j['min_date']),
        maxDate: _s(j['max_date']),
        minYear: _iOrNull(j['min_year']),
        maxYear: _iOrNull(j['max_year']),
      );
}

// ─────────────────────── Proker Midlife Eng Booster ────────────────────────

class BoosterUnit {
  final String cn;
  final int? no;
  final String? unitModel;
  final String? product;
  final String? unitType;
  final double? hmNow;
  final double intervalHm;
  final String? remarks;
  final int eventCount;
  final double? ovhHm;
  final String? ovhDate;
  final double? mlHm;
  final String? mlDate;
  final double? lastHm;
  final String? lastKind;
  final String? lastDate;
  final double nextPlanHm;
  final double? hoursToGo;
  final double? lifetimeEg;
  final double? lifetimeMid;

  const BoosterUnit({
    required this.cn,
    this.no,
    this.unitModel,
    this.product,
    this.unitType,
    this.hmNow,
    this.intervalHm = 20000,
    this.remarks,
    this.eventCount = 0,
    this.ovhHm,
    this.ovhDate,
    this.mlHm,
    this.mlDate,
    this.lastHm,
    this.lastKind,
    this.lastDate,
    this.nextPlanHm = 0,
    this.hoursToGo,
    this.lifetimeEg,
    this.lifetimeMid,
  });

  factory BoosterUnit.fromJson(Map<String, dynamic> j) => BoosterUnit(
        cn: '${j['cn'] ?? ''}',
        no: _iOrNull(j['no']),
        unitModel: _s(j['unit_model']),
        product: _s(j['product']),
        unitType: _s(j['unit_type']),
        hmNow: _d(j['hm_now']),
        intervalHm: _d(j['interval_hm']) ?? 20000,
        remarks: _s(j['remarks']),
        eventCount: _i(j['event_count']),
        ovhHm: _d(j['ovh_hm']),
        ovhDate: _s(j['ovh_date']),
        mlHm: _d(j['ml_hm']),
        mlDate: _s(j['ml_date']),
        lastHm: _d(j['last_hm']),
        lastKind: _s(j['last_kind'])?.toUpperCase(),
        lastDate: _s(j['last_date']),
        nextPlanHm: _d(j['next_plan_hm']) ?? 0,
        hoursToGo: _d(j['hours_to_go']),
        lifetimeEg: _d(j['lifetime_eg']),
        lifetimeMid: _d(j['lifetime_mid']),
      );

  String get modelLabel => unitModel ?? '-';

  String get productTypeLabel {
    final p = product ?? '';
    final t = unitType ?? '';
    if (p.isNotEmpty && t.isNotEmpty) return '$p · $t';
    return p.isEmpty ? t : p;
  }
}

class BoosterEvent {
  final int id;
  final String cn;
  final String kind; // OVH | MIDLIFE
  final double hm;
  final String? serviceDate;
  final String? note;

  const BoosterEvent({
    required this.id,
    this.cn = '',
    this.kind = 'MIDLIFE',
    this.hm = 0,
    this.serviceDate,
    this.note,
  });

  factory BoosterEvent.fromJson(Map<String, dynamic> j) => BoosterEvent(
        id: _i(j['id']),
        cn: '${j['cn'] ?? ''}',
        kind: '${j['kind'] ?? 'MIDLIFE'}'.toUpperCase(),
        hm: _d(j['hm']) ?? 0,
        serviceDate: _s(j['service_date']),
        note: _s(j['note']),
      );
}

class BoosterDetailStats {
  final int events;
  final int ovh;
  final int midlife;
  final double? hmNow;
  final double intervalHm;
  final double? lastHm;
  final String? lastKind;
  final String? lastDate;
  final double nextPlanHm;
  final double? hoursToGo;
  final double? lifetimeEg;
  final double? lifetimeMid;
  final bool due;

  const BoosterDetailStats({
    this.events = 0,
    this.ovh = 0,
    this.midlife = 0,
    this.hmNow,
    this.intervalHm = 20000,
    this.lastHm,
    this.lastKind,
    this.lastDate,
    this.nextPlanHm = 0,
    this.hoursToGo,
    this.lifetimeEg,
    this.lifetimeMid,
    this.due = false,
  });

  factory BoosterDetailStats.fromJson(Map<String, dynamic> j) =>
      BoosterDetailStats(
        events: _i(j['events']),
        ovh: _i(j['ovh']),
        midlife: _i(j['midlife']),
        hmNow: _d(j['hm_now']),
        intervalHm: _d(j['interval_hm']) ?? 20000,
        lastHm: _d(j['last_hm']),
        lastKind: _s(j['last_kind'])?.toUpperCase(),
        lastDate: _s(j['last_date']),
        nextPlanHm: _d(j['next_plan_hm']) ?? 0,
        hoursToGo: _d(j['hours_to_go']),
        lifetimeEg: _d(j['lifetime_eg']),
        lifetimeMid: _d(j['lifetime_mid']),
        due: j['due'] == true,
      );
}

class BoosterDetail {
  final BoosterUnit unit;
  final List<BoosterEvent> events;
  final BoosterDetailStats stats;

  const BoosterDetail({
    required this.unit,
    this.events = const [],
    this.stats = const BoosterDetailStats(),
  });

  factory BoosterDetail.fromJson(Map<String, dynamic> j) => BoosterDetail(
        unit: BoosterUnit.fromJson(_map(j['unit'])),
        events: [
          for (final e in _mapList(j['events'])) BoosterEvent.fromJson(e),
        ],
        stats: BoosterDetailStats.fromJson(_map(j['stats'])),
      );
}

class BoosterKpi {
  final int units;
  final int total;
  final int ovh;
  final int midlife;
  final int unitEvent;
  final int due;
  final String? lastDate;
  final double interval;

  const BoosterKpi({
    this.units = 0,
    this.total = 0,
    this.ovh = 0,
    this.midlife = 0,
    this.unitEvent = 0,
    this.due = 0,
    this.lastDate,
    this.interval = 20000,
  });

  factory BoosterKpi.fromJson(Map<String, dynamic> j) => BoosterKpi(
        units: _i(j['units']),
        total: _i(j['total']),
        ovh: _i(j['ovh']),
        midlife: _i(j['midlife']),
        unitEvent: _i(j['unit_event']),
        due: _i(j['due']),
        lastDate: _s(j['last_date']),
        interval: _d(j['interval']) ?? 20000,
      );
}

class BoosterFilters {
  final List<String> product;
  final List<String> model;
  final List<String> type;
  final double interval;
  final String? minDate;
  final String? maxDate;

  const BoosterFilters({
    this.product = const [],
    this.model = const [],
    this.type = const [],
    this.interval = 20000,
    this.minDate,
    this.maxDate,
  });

  factory BoosterFilters.fromJson(Map<String, dynamic> j) => BoosterFilters(
        product: _sList(j['product']),
        model: _sList(j['model']),
        type: _sList(j['type']),
        interval: _d(j['interval']) ?? 20000,
        minDate: _s(j['min_date']),
        maxDate: _s(j['max_date']),
      );
}

// ───────────────────── Proker Midlife Injector Primer ──────────────────────

class InjectorUnit {
  final String cn;
  final int? no;
  final String? unitModel;
  final String? product;
  final String? unitType;
  final double? hmNow;
  final double intervalHm;
  final int replCount;
  final int doneCount;
  final int planCount;
  final double? lastHm;
  final int? lastSeq;
  final double? ageHm;
  final double nextPlanHm;
  final double? hoursToGo;

  const InjectorUnit({
    required this.cn,
    this.no,
    this.unitModel,
    this.product,
    this.unitType,
    this.hmNow,
    this.intervalHm = 16000,
    this.replCount = 0,
    this.doneCount = 0,
    this.planCount = 0,
    this.lastHm,
    this.lastSeq,
    this.ageHm,
    this.nextPlanHm = 0,
    this.hoursToGo,
  });

  factory InjectorUnit.fromJson(Map<String, dynamic> j) => InjectorUnit(
        cn: '${j['cn'] ?? ''}',
        no: _iOrNull(j['no']),
        unitModel: _s(j['unit_model']),
        product: _s(j['product']),
        unitType: _s(j['unit_type']),
        hmNow: _d(j['hm_now']),
        intervalHm: _d(j['interval_hm']) ?? 16000,
        replCount: _i(j['repl_count']),
        doneCount: _i(j['done_count']),
        planCount: _i(j['plan_count']),
        lastHm: _d(j['last_hm']),
        lastSeq: _iOrNull(j['last_seq']),
        ageHm: _d(j['age_hm']),
        nextPlanHm: _d(j['next_plan_hm']) ?? 0,
        hoursToGo: _d(j['hours_to_go']),
      );

  String get modelLabel => unitModel ?? '-';

  String get productTypeLabel {
    final p = product ?? '';
    final t = unitType ?? '';
    if (p.isNotEmpty && t.isNotEmpty) return '$p · $t';
    return p.isEmpty ? t : p;
  }
}

class InjectorReplacement {
  final int id;
  final String cn;
  final int seq;
  final int position;
  final double? hm;
  final String status; // DONE | PLAN
  final String? note;

  const InjectorReplacement({
    required this.id,
    this.cn = '',
    this.seq = 0,
    this.position = 0,
    this.hm,
    this.status = 'DONE',
    this.note,
  });

  factory InjectorReplacement.fromJson(Map<String, dynamic> j) =>
      InjectorReplacement(
        id: _i(j['id']),
        cn: '${j['cn'] ?? ''}',
        seq: _i(j['seq']),
        position: _i(j['position']),
        hm: _d(j['hm']),
        status: '${j['status'] ?? 'DONE'}'.toUpperCase(),
        note: _s(j['note']),
      );
}

class InjectorPosition {
  final int position;
  final int? seq;
  final double? hm;
  final String? status; // DONE | PLAN
  final double? age;

  const InjectorPosition({
    required this.position,
    this.seq,
    this.hm,
    this.status,
    this.age,
  });

  factory InjectorPosition.fromJson(Map<String, dynamic> j) => InjectorPosition(
        position: _i(j['position']),
        seq: _iOrNull(j['seq']),
        hm: _d(j['hm']),
        status: _s(j['status'])?.toUpperCase(),
        age: _d(j['age']),
      );
}

class InjectorDetailStats {
  final int replacements;
  final int done;
  final int plan;
  final double? hmNow;
  final double intervalHm;
  final double? lastHm;
  final int? lastSeq;
  final double? ageHm;
  final double nextPlanHm;
  final double? hoursToGo;
  final bool due;

  const InjectorDetailStats({
    this.replacements = 0,
    this.done = 0,
    this.plan = 0,
    this.hmNow,
    this.intervalHm = 16000,
    this.lastHm,
    this.lastSeq,
    this.ageHm,
    this.nextPlanHm = 0,
    this.hoursToGo,
    this.due = false,
  });

  factory InjectorDetailStats.fromJson(Map<String, dynamic> j) =>
      InjectorDetailStats(
        replacements: _i(j['replacements']),
        done: _i(j['done']),
        plan: _i(j['plan']),
        hmNow: _d(j['hm_now']),
        intervalHm: _d(j['interval_hm']) ?? 16000,
        lastHm: _d(j['last_hm']),
        lastSeq: _iOrNull(j['last_seq']),
        ageHm: _d(j['age_hm']),
        nextPlanHm: _d(j['next_plan_hm']) ?? 0,
        hoursToGo: _d(j['hours_to_go']),
        due: j['due'] == true,
      );
}

class InjectorDetail {
  final InjectorUnit unit;
  final List<InjectorReplacement> replacements;
  final List<InjectorPosition> positions;
  final InjectorDetailStats stats;

  const InjectorDetail({
    required this.unit,
    this.replacements = const [],
    this.positions = const [],
    this.stats = const InjectorDetailStats(),
  });

  factory InjectorDetail.fromJson(Map<String, dynamic> j) => InjectorDetail(
        unit: InjectorUnit.fromJson(_map(j['unit'])),
        replacements: [
          for (final e in _mapList(j['replacements']))
            InjectorReplacement.fromJson(e),
        ],
        positions: [
          for (final e in _mapList(j['positions'])) InjectorPosition.fromJson(e),
        ],
        stats: InjectorDetailStats.fromJson(_map(j['stats'])),
      );
}

class InjectorKpi {
  final int units;
  final int total;
  final int done;
  final int plan;
  final int unitWithRepl;
  final int due;
  final double interval;
  final int positions;

  const InjectorKpi({
    this.units = 0,
    this.total = 0,
    this.done = 0,
    this.plan = 0,
    this.unitWithRepl = 0,
    this.due = 0,
    this.interval = 16000,
    this.positions = 12,
  });

  factory InjectorKpi.fromJson(Map<String, dynamic> j) => InjectorKpi(
        units: _i(j['units']),
        total: _i(j['total']),
        done: _i(j['done']),
        plan: _i(j['plan']),
        unitWithRepl: _i(j['unit_with_repl']),
        due: _i(j['due']),
        interval: _d(j['interval']) ?? 16000,
        positions: _i(j['positions']) == 0 ? 12 : _i(j['positions']),
      );
}

class InjectorFilters {
  final List<String> product;
  final List<String> model;
  final List<String> type;
  final double interval;
  final int positions;

  const InjectorFilters({
    this.product = const [],
    this.model = const [],
    this.type = const [],
    this.interval = 16000,
    this.positions = 12,
  });

  factory InjectorFilters.fromJson(Map<String, dynamic> j) => InjectorFilters(
        product: _sList(j['product']),
        model: _sList(j['model']),
        type: _sList(j['type']),
        interval: _d(j['interval']) ?? 16000,
        positions: _i(j['positions']) == 0 ? 12 : _i(j['positions']),
      );
}

// ───────────────────────── Proker Thermostat CAT ───────────────────────────

class ThermostatUnit {
  final String cn;
  final int? no;
  final String? unitModel;
  final String? product;
  final String? unitType;
  final double? hmNow;
  final double intervalHm;
  final double? lastHm;
  final String? lastDate;
  final double? modifHm;
  final String? modifDate;
  final String? modifStatus;
  final String? wr;
  final String? etaParts;
  final String? etaExec;
  final double? radHm;
  final String? radDate;
  final double? radUpper;
  final double? radLower;
  final String? radRemark;
  final double? deviasi;
  final double? lifetime;
  final bool due;

  const ThermostatUnit({
    required this.cn,
    this.no,
    this.unitModel,
    this.product,
    this.unitType,
    this.hmNow,
    this.intervalHm = 12000,
    this.lastHm,
    this.lastDate,
    this.modifHm,
    this.modifDate,
    this.modifStatus,
    this.wr,
    this.etaParts,
    this.etaExec,
    this.radHm,
    this.radDate,
    this.radUpper,
    this.radLower,
    this.radRemark,
    this.deviasi,
    this.lifetime,
    this.due = false,
  });

  factory ThermostatUnit.fromJson(Map<String, dynamic> j) => ThermostatUnit(
        cn: '${j['cn'] ?? ''}',
        no: _iOrNull(j['no']),
        unitModel: _s(j['unit_model']),
        product: _s(j['product']),
        unitType: _s(j['unit_type']),
        hmNow: _d(j['hm_now']),
        intervalHm: _d(j['interval_hm']) ?? 12000,
        lastHm: _d(j['last_hm']),
        lastDate: _s(j['last_date']),
        modifHm: _d(j['modif_hm']),
        modifDate: _s(j['modif_date']),
        modifStatus: _s(j['modif_status'])?.toUpperCase(),
        wr: _s(j['wr']),
        etaParts: _s(j['eta_parts']),
        etaExec: _s(j['eta_exec']),
        radHm: _d(j['rad_hm']),
        radDate: _s(j['rad_date']),
        radUpper: _d(j['rad_upper']),
        radLower: _d(j['rad_lower']),
        radRemark: _s(j['rad_remark']),
        deviasi: _d(j['deviasi']),
        lifetime: _d(j['lifetime']),
        due: j['due'] == true,
      );

  String get modelLabel => unitModel ?? '-';

  String get productTypeLabel {
    final p = product ?? '';
    final t = unitType ?? '';
    if (p.isNotEmpty && t.isNotEmpty) return '$p · $t';
    return p.isEmpty ? t : p;
  }

  /// Status modif 74°C efektif: kosong dianggap NOT YET (perilaku web).
  String get modifStatusLabel =>
      (modifStatus == null || modifStatus!.isEmpty) ? 'NOT YET' : modifStatus!;
}

class ThermostatKpi {
  final int units;
  final int done;
  final int notYet;
  final int due;
  final double interval;
  final String? lastDate;

  const ThermostatKpi({
    this.units = 0,
    this.done = 0,
    this.notYet = 0,
    this.due = 0,
    this.interval = 12000,
    this.lastDate,
  });

  factory ThermostatKpi.fromJson(Map<String, dynamic> j) => ThermostatKpi(
        units: _i(j['units']),
        done: _i(j['done']),
        notYet: _i(j['not_yet']),
        due: _i(j['due']),
        interval: _d(j['interval']) ?? 12000,
        lastDate: _s(j['last_date']),
      );
}

class ThermostatFilters {
  final List<String> product;
  final List<String> model;
  final List<String> type;
  final double interval;

  const ThermostatFilters({
    this.product = const [],
    this.model = const [],
    this.type = const [],
    this.interval = 12000,
  });

  factory ThermostatFilters.fromJson(Map<String, dynamic> j) =>
      ThermostatFilters(
        product: _sList(j['product']),
        model: _sList(j['model']),
        type: _sList(j['type']),
        interval: _d(j['interval']) ?? 12000,
      );
}
