// Model Ewacs Performance — kontrak ewacs.py + client.ts.
// KPI Physical Availability + ratio SCM/USM dari data breakdown.

class EwacsKpi {
  final double pa;
  final double scmDur;
  final double usmDur;
  final double scmPct;
  final double usmPct;
  final int unitCount;
  final int dayCount;
  final double totalDowntime;

  const EwacsKpi({
    this.pa = 0,
    this.scmDur = 0,
    this.usmDur = 0,
    this.scmPct = 0,
    this.usmPct = 0,
    this.unitCount = 0,
    this.dayCount = 0,
    this.totalDowntime = 0,
  });

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

  factory EwacsKpi.fromJson(Map<String, dynamic> j) => EwacsKpi(
        pa: _d(j['pa']),
        scmDur: _d(j['scm_dur']),
        usmDur: _d(j['usm_dur']),
        scmPct: _d(j['scm_pct']),
        usmPct: _d(j['usm_pct']),
        unitCount: (j['unit_count'] as num?)?.toInt() ?? 0,
        dayCount: (j['day_count'] as num?)?.toInt() ?? 0,
        totalDowntime: _d(j['total_downtime']),
      );
}

/// Satu titik tren harian: PA %, durasi SCM & USM.
class EwacsTrend {
  final String tanggal;
  final double scmDur;
  final double usmDur;
  final double pa;

  const EwacsTrend({
    required this.tanggal,
    this.scmDur = 0,
    this.usmDur = 0,
    this.pa = 0,
  });

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

  factory EwacsTrend.fromJson(Map<String, dynamic> j) => EwacsTrend(
        tanggal: '${j['tanggal'] ?? ''}',
        scmDur: _d(j['scm_dur']),
        usmDur: _d(j['usm_dur']),
        pa: _d(j['pa']),
      );
}

/// Satu baris tabel detail breakdown.
class EwacsDetail {
  final int id;
  final String tanggal;
  final String? crew;
  final String cn;
  final String? egi;
  final String? troubleDesc;
  final String? shift;
  final String kode;
  final String? wo;
  final String? lokasi;
  final String? startBd;
  final String? mekanikDatang;
  final String? rfu;
  final String? operatorDatang;
  final double durasi;
  final String? mekanik;
  final String? action;

  const EwacsDetail({
    required this.id,
    required this.tanggal,
    this.crew,
    required this.cn,
    this.egi,
    this.troubleDesc,
    this.shift,
    required this.kode,
    this.wo,
    this.lokasi,
    this.startBd,
    this.mekanikDatang,
    this.rfu,
    this.operatorDatang,
    this.durasi = 0,
    this.mekanik,
    this.action,
  });

  factory EwacsDetail.fromJson(Map<String, dynamic> j) {
    var t = '${j['tanggal'] ?? ''}';
    if (t.length >= 10) t = t.substring(0, 10);
    return EwacsDetail(
      id: (j['id'] as num?)?.toInt() ?? 0,
      tanggal: t,
      crew: j['crew']?.toString(),
      cn: '${j['cn'] ?? ''}',
      egi: j['egi']?.toString(),
      troubleDesc: j['trouble_desc']?.toString(),
      shift: j['shift']?.toString(),
      kode: '${j['kode'] ?? ''}',
      wo: j['wo']?.toString(),
      lokasi: j['lokasi']?.toString(),
      startBd: j['start_bd']?.toString(),
      mekanikDatang: j['mekanik_datang']?.toString(),
      rfu: j['rfu']?.toString(),
      operatorDatang: j['operator_datang']?.toString(),
      durasi: (j['durasi'] as num?)?.toDouble() ?? 0,
      mekanik: j['mekanik']?.toString(),
      action: j['action']?.toString(),
    );
  }
}

/// Nilai unik untuk dropdown filter.
class EwacsFilters {
  final List<String> egi;
  final List<String> crew;
  final List<String> cn;

  const EwacsFilters({this.egi = const [], this.crew = const [], this.cn = const []});

  factory EwacsFilters.fromJson(Map<String, dynamic> j) => EwacsFilters(
        egi: ((j['egi'] as List? ?? []).map((e) => '$e')).toList(),
        crew: ((j['crew'] as List? ?? []).map((e) => '$e')).toList(),
        cn: ((j['cn'] as List? ?? []).map((e) => '$e')).toList(),
      );
}

/// Hasil import CSV.
class EwacsImportResult {
  final int inserted, updated, deleted, skipped, duplicates, totalRows;

  const EwacsImportResult({
    this.inserted = 0,
    this.updated = 0,
    this.deleted = 0,
    this.skipped = 0,
    this.duplicates = 0,
    this.totalRows = 0,
  });

  factory EwacsImportResult.fromJson(Map<String, dynamic> j) => EwacsImportResult(
        inserted: (j['inserted'] as num?)?.toInt() ?? 0,
        updated: (j['updated'] as num?)?.toInt() ?? 0,
        deleted: (j['deleted'] as num?)?.toInt() ?? 0,
        skipped: (j['skipped'] as num?)?.toInt() ?? 0,
        duplicates: (j['duplicates'] as num?)?.toInt() ?? 0,
        totalRows: (j['total_rows'] as num?)?.toInt() ?? 0,
      );
}

/// Kode breakdown yang tersedia pada dropdown web.
const List<String> ewacsKodes = ['SCM', 'USM', 'TSM', 'TUM', 'ICM', 'ISM'];
