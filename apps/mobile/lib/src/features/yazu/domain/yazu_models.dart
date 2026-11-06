// Model Yazu (P2H) & Yazu Daily Check — kontrak yazu.py / yazu_dc.py
// + client.ts. Keduanya berbentuk identik: pivot baris = ID Unit,
// kolom = tanggal 1..akhir bulan, sel = HM terakhir hari itu.

/// Pivot bulanan Yazu: unit + sel per hari.
class YazuPivot {
  final int year;
  final int month;
  final int daysInMonth;
  final List<String> units;

  /// cells[unit][day] = HM (null bila tak ada pembacaan hari itu).
  final Map<String, Map<int, int?>> cells;

  const YazuPivot({
    required this.year,
    required this.month,
    required this.daysInMonth,
    this.units = const [],
    this.cells = const {},
  });

  factory YazuPivot.fromJson(Map<String, dynamic> j) {
    final rawCells = (j['cells'] as Map? ?? {});
    final cells = <String, Map<int, int?>>{};
    rawCells.forEach((k, v) {
      final inner = (v as Map? ?? {});
      cells['$k'] = inner.map((dk, dv) =>
          MapEntry(int.tryParse('$dk') ?? 0, (dv as num?)?.toInt()));
    });
    return YazuPivot(
      year: (j['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (j['month'] as num?)?.toInt() ?? DateTime.now().month,
      daysInMonth: (j['days_in_month'] as num?)?.toInt() ?? 31,
      units: ((j['units'] as List? ?? []).map((e) => '$e')).toList(),
      cells: cells,
    );
  }
}

/// Satu baris log sync pada /stats.
class YazuSyncLog {
  final String? startedAt;
  final String? finishedAt;
  final String? status;
  final int? rowsTotal;
  final int? rowsUpserted;
  final String? errorMsg;

  const YazuSyncLog({
    this.startedAt,
    this.finishedAt,
    this.status,
    this.rowsTotal,
    this.rowsUpserted,
    this.errorMsg,
  });

  factory YazuSyncLog.fromJson(Map<String, dynamic> j) => YazuSyncLog(
        startedAt: j['started_at']?.toString(),
        finishedAt: j['finished_at']?.toString(),
        status: j['status']?.toString(),
        rowsTotal: (j['rows_total'] as num?)?.toInt(),
        rowsUpserted: (j['rows_upserted'] as num?)?.toInt(),
        errorMsg: j['error_msg']?.toString(),
      );
}

/// Statistik /stats (sama untuk yazu & yazu-dc).
class YazuStats {
  final int totalRows;
  final int totalUnits;
  final String? lastDataWaktu;
  final YazuSyncLog? lastSync;

  const YazuStats({
    this.totalRows = 0,
    this.totalUnits = 0,
    this.lastDataWaktu,
    this.lastSync,
  });

  factory YazuStats.fromJson(Map<String, dynamic> j) => YazuStats(
        totalRows: (j['total_rows'] as num?)?.toInt() ?? 0,
        totalUnits: (j['total_units'] as num?)?.toInt() ?? 0,
        lastDataWaktu: j['last_data_waktu']?.toString(),
        lastSync: j['last_sync'] == null
            ? null
            : YazuSyncLog.fromJson(
                (j['last_sync'] as Map).cast<String, dynamic>()),
      );
}

/// Hasil POST /sync: { status, rows_total, rows_upserted, error_msg? }.
class YazuSyncResult {
  final String status;
  final int rowsTotal;
  final int rowsUpserted;

  const YazuSyncResult({
    this.status = '',
    this.rowsTotal = 0,
    this.rowsUpserted = 0,
  });

  factory YazuSyncResult.fromJson(Map<String, dynamic> j) => YazuSyncResult(
        status: '${j['status'] ?? ''}',
        rowsTotal: (j['rows_total'] as num?)?.toInt() ?? 0,
        rowsUpserted: (j['rows_upserted'] as num?)?.toInt() ?? 0,
      );
}

/// Kenaikan HM rata-rata per hari per unit (web computeDeltas):
/// delta hari ini vs hari berdata sebelumnya, dinormalisasi / jarak hari.
Map<String, Map<int, double>> yazuComputeDeltas(YazuPivot p) {
  final out = <String, Map<int, double>>{};
  for (final uid in p.units) {
    final dm = p.cells[uid];
    if (dm == null) continue;
    final days = dm.keys.toList()..sort();
    final ud = <int, double>{};
    for (var i = 1; i < days.length; i++) {
      final cur = days[i];
      final prev = days[i - 1];
      final gap = cur - prev;
      if (gap <= 0) continue;
      final curHm = dm[cur];
      final prevHm = dm[prev];
      if (curHm == null || prevHm == null) continue;
      ud[cur] = (curHm - prevHm) / gap;
    }
    out[uid] = ud;
  }
  return out;
}

/// Kategori warna delta (web deltaColor):
///  - mundur  : delta < 0 → background merah, teks putih, bold
///  - merah   : > 24 (anomali)
///  - orange  : 14–24 (di atas normal)
///  - hijau   : 10–14 (normal)
///  - biasa   : 0–10 (default)
enum YazuDeltaLevel { none, biasa, hijau, orange, merah, mundur }

YazuDeltaLevel yazuDeltaLevel(double? delta) {
  if (delta == null) return YazuDeltaLevel.none;
  if (delta < 0) return YazuDeltaLevel.mundur;
  if (delta > 24) return YazuDeltaLevel.merah;
  if (delta > 14) return YazuDeltaLevel.orange;
  if (delta >= 10) return YazuDeltaLevel.hijau;
  return YazuDeltaLevel.biasa;
}

/// Ringkasan anomali (web anomalySummary).
class YazuAnomalySummary {
  final int mundur, merah, orange, hijau, biasa;
  const YazuAnomalySummary({
    this.mundur = 0,
    this.merah = 0,
    this.orange = 0,
    this.hijau = 0,
    this.biasa = 0,
  });
}

YazuAnomalySummary yazuAnomalySummary(
    Map<String, Map<int, double>> deltas) {
  var mundur = 0, merah = 0, orange = 0, hijau = 0, biasa = 0;
  for (final ud in deltas.values) {
    for (final delta in ud.values) {
      switch (yazuDeltaLevel(delta)) {
        case YazuDeltaLevel.mundur:
          mundur++;
        case YazuDeltaLevel.merah:
          merah++;
        case YazuDeltaLevel.orange:
          orange++;
        case YazuDeltaLevel.hijau:
          hijau++;
        case YazuDeltaLevel.biasa:
        case YazuDeltaLevel.none:
          biasa++;
      }
    }
  }
  return YazuAnomalySummary(
      mundur: mundur, merah: merah, orange: orange, hijau: hijau, biasa: biasa);
}

/// Label tooltip sel (web title).
String yazuDeltaTitle(double delta) => delta < 0
    ? 'ANOMALI: HM mundur ${delta.toStringAsFixed(1)} jam/hari'
    : 'Δ ${delta.toStringAsFixed(1)} jam/hari';

/// Nama bulan Indonesia (web MONTHS).
const List<String> yazuMonths = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
