// Model Hourmeter — kontrak apps/api/app/api/v1/hourmeter.py + client.ts.
// Pivot: baris = CN unit, kolom = Opening + hari 1..31 + Akhir + Selisih.
// Sumber: upload Excel manual (sheet HM_Manual); upload mengganti seluruh
// data periode terpilih.

/// Satu unit pada grid HM: nilai opening, nilai harian (kunci "1".."31"),
/// pembacaan terakhir (final) & selisih (final − opening).
class HourmeterUnit {
  final String cn;
  final String? egi;
  final int? opening;
  final Map<String, int> vals;
  final int? lastDay;
  final int? finalHm;
  final int? delta;

  const HourmeterUnit({
    required this.cn,
    this.egi,
    this.opening,
    this.vals = const {},
    this.lastDay,
    this.finalHm,
    this.delta,
  });

  factory HourmeterUnit.fromJson(Map<String, dynamic> j) {
    final raw = (j['vals'] as Map? ?? {});
    return HourmeterUnit(
      cn: '${j['cn'] ?? ''}',
      egi: j['egi']?.toString(),
      opening: (j['opening'] as num?)?.toInt(),
      vals: raw.map((k, v) => MapEntry('$k', (v as num).toInt())),
      lastDay: (j['last_day'] as num?)?.toInt(),
      finalHm: (j['final'] as num?)?.toInt(),
      delta: (j['delta'] as num?)?.toInt(),
    );
  }
}

/// Pivot HM satu periode (bulan) + jumlah hari pada bulan itu.
class HourmeterPivot {
  final String period;
  final int daysInMonth;
  final List<HourmeterUnit> units;

  const HourmeterPivot({
    required this.period,
    required this.daysInMonth,
    this.units = const [],
  });

  factory HourmeterPivot.fromJson(Map<String, dynamic> j) => HourmeterPivot(
        period: '${j['period'] ?? ''}',
        daysInMonth: (j['days_in_month'] as num?)?.toInt() ?? 31,
        units: ((j['units'] as List? ?? []))
            .map((e) => HourmeterUnit.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// Ringkasan satu periode pada /stats.
class HourmeterPeriod {
  final String period;
  final int units;
  final int valuesCnt;
  final String? uploadedAt;
  final String? uploadedBy;

  const HourmeterPeriod({
    required this.period,
    this.units = 0,
    this.valuesCnt = 0,
    this.uploadedAt,
    this.uploadedBy,
  });

  factory HourmeterPeriod.fromJson(Map<String, dynamic> j) => HourmeterPeriod(
        period: '${j['period'] ?? ''}',
        units: (j['units'] as num?)?.toInt() ?? 0,
        valuesCnt: (j['values_cnt'] as num?)?.toInt() ?? 0,
        uploadedAt: j['uploaded_at']?.toString(),
        uploadedBy: j['uploaded_by']?.toString(),
      );
}

/// Satu baris log upload pada /stats.
class HourmeterLog {
  final String period;
  final String? filename;
  final int rowsUnits;
  final int rowsValues;
  final String? status;
  final String? errorMsg;
  final String? uploadedBy;
  final String? uploadedAt;

  const HourmeterLog({
    required this.period,
    this.filename,
    this.rowsUnits = 0,
    this.rowsValues = 0,
    this.status,
    this.errorMsg,
    this.uploadedBy,
    this.uploadedAt,
  });

  factory HourmeterLog.fromJson(Map<String, dynamic> j) => HourmeterLog(
        period: '${j['period'] ?? ''}',
        filename: j['filename']?.toString(),
        rowsUnits: (j['rows_units'] as num?)?.toInt() ?? 0,
        rowsValues: (j['rows_values'] as num?)?.toInt() ?? 0,
        status: j['status']?.toString(),
        errorMsg: j['error_msg']?.toString(),
        uploadedBy: j['uploaded_by']?.toString(),
        uploadedAt: j['uploaded_at']?.toString(),
      );
}

/// Ringkasan /stats: daftar periode + log upload terakhir.
class HourmeterStats {
  final List<HourmeterPeriod> periods;
  final List<HourmeterLog> logs;

  const HourmeterStats({this.periods = const [], this.logs = const []});

  factory HourmeterStats.fromJson(Map<String, dynamic> j) => HourmeterStats(
        periods: ((j['periods'] as List? ?? []))
            .map((e) =>
                HourmeterPeriod.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        logs: ((j['logs'] as List? ?? []))
            .map((e) => HourmeterLog.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// Hasil upload: { ok, period, units, values }.
class HourmeterUploadResult {
  final String period;
  final int units;
  final int values;

  const HourmeterUploadResult({
    required this.period,
    this.units = 0,
    this.values = 0,
  });

  factory HourmeterUploadResult.fromJson(Map<String, dynamic> j) =>
      HourmeterUploadResult(
        period: '${j['period'] ?? ''}',
        units: (j['units'] as num?)?.toInt() ?? 0,
        values: (j['values'] as num?)?.toInt() ?? 0,
      );
}

/// Nama bulan Indonesia (web MONTHS).
const List<String> hourmeterMonths = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
