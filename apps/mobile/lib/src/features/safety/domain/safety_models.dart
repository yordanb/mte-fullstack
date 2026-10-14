/// Model Safety Bomak + R1BI — kontrak safety.py, r1bi.py + client.ts:235-311.

/// Nama >2 kata jadi 2 kata + 1 huruf (cth RAHMAT FITRIADI M).
String shortName(String? v) {
  final parts = (v ?? '').split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.length > 2) return '${parts[0]} ${parts[1]} ${parts[2][0]}';
  return v ?? '';
}

/// Akhir bulan YYYY-MM-DD (pengganti trik web `new Date(y, m, 0)`).
String monthEnd(int year, int month) {
  final last = DateTime(year, month + 1, 0).day;
  final mm = month.toString().padLeft(2, '0');
  final dd = last.toString().padLeft(2, '0');
  return '$year-$mm-$dd';
}

String monthStart(int year, int month) {
  final mm = month.toString().padLeft(2, '0');
  return '$year-$mm-01';
}

/// dd/MM/yy dari YYYY-MM-DD (teks salinan WA).
String waShortDate(String? isoDate) {
  if (isoDate == null || isoDate.length < 10) return isoDate ?? '';
  final p = isoDate.substring(0, 10).split('-');
  if (p.length != 3) return isoDate;
  return '${p[2]}/${p[1]}/${p[0].substring(2)}';
}

/// dd/MM/yyyy dari YYYY-MM-DD (kolom tanggal, aman tanpa parse zona).
String ddmmyyyy(String? isoDate) {
  if (isoDate == null || isoDate.length < 10) return isoDate ?? '';
  final p = isoDate.substring(0, 10).split('-');
  if (p.length != 3) return isoDate;
  return '${p[2]}/${p[1]}/${p[0]}';
}

class SafetyCoverageRow {
  final String? section;
  final int n;
  final int mekanik;
  final int pengawas;
  final int hari;
  final String? terakhir;

  const SafetyCoverageRow({
    this.section,
    this.n = 0,
    this.mekanik = 0,
    this.pengawas = 0,
    this.hari = 0,
    this.terakhir,
  });

  factory SafetyCoverageRow.fromJson(Map<String, dynamic> j) => SafetyCoverageRow(
        section: j['section']?.toString(),
        n: (j['n'] as num?)?.toInt() ?? 0,
        mekanik: (j['mekanik'] as num?)?.toInt() ?? 0,
        pengawas: (j['pengawas'] as num?)?.toInt() ?? 0,
        hari: (j['hari'] as num?)?.toInt() ?? 0,
        terakhir: j['terakhir']?.toString(),
      );
}

class SafetyCompliance {
  final int total;
  final List<int> issues; // x0..x6 per COMP_LABELS
  final int p6Empty;
  final int fuEmpty;

  const SafetyCompliance({
    this.total = 0,
    this.issues = const [0, 0, 0, 0, 0, 0, 0],
    this.p6Empty = 0,
    this.fuEmpty = 0,
  });

  factory SafetyCompliance.fromJson(Map<String, dynamic>? j) => SafetyCompliance(
        total: (j?['total'] as num?)?.toInt() ?? 0,
        issues: [for (var i = 0; i < 7; i++) (j?['x$i'] as num?)?.toInt() ?? 0],
        p6Empty: (j?['p6_empty'] as num?)?.toInt() ?? 0,
        fuEmpty: (j?['fu_empty'] as num?)?.toInt() ?? 0,
      );
}

class SafetyRow {
  final int id;
  final String submittedAt;
  final String? pengawasNama;
  final String? pengawasNrp;
  final String? mekanikNama;
  final String? mekanikNrp;
  final String? grade;
  final String? section;
  final String? p1Doa;
  final String? p2Apd;
  final String? p2Stretch;
  final String? p3Housekeeping;
  final String? p3Desc;
  final String? p4Alat;
  final String? p4Desc;
  final String? p5Prosedur;
  final String? p6Desc;
  final String? followup;
  final String? vlogUrl;
  final String? vlogFile;
  final String? vlogDesc;
  final String? areaBomak;
  final String? jobDesc;

  const SafetyRow({
    required this.id,
    required this.submittedAt,
    this.pengawasNama,
    this.pengawasNrp,
    this.mekanikNama,
    this.mekanikNrp,
    this.grade,
    this.section,
    this.p1Doa,
    this.p2Apd,
    this.p2Stretch,
    this.p3Housekeeping,
    this.p3Desc,
    this.p4Alat,
    this.p4Desc,
    this.p5Prosedur,
    this.p6Desc,
    this.followup,
    this.vlogUrl,
    this.vlogFile,
    this.vlogDesc,
    this.areaBomak,
    this.jobDesc,
  });

  static String? _s(Map<String, dynamic> j, String k) => j[k]?.toString();

  factory SafetyRow.fromJson(Map<String, dynamic> j) => SafetyRow(
        id: (j['id'] as num?)?.toInt() ?? 0,
        submittedAt: '${j['submitted_at'] ?? ''}',
        pengawasNama: _s(j, 'pengawas_nama'),
        pengawasNrp: _s(j, 'pengawas_nrp'),
        mekanikNama: _s(j, 'mekanik_nama'),
        mekanikNrp: _s(j, 'mekanik_nrp'),
        grade: _s(j, 'grade'),
        section: _s(j, 'section'),
        p1Doa: _s(j, 'p1_doa'),
        p2Apd: _s(j, 'p2_apd'),
        p2Stretch: _s(j, 'p2_stretch'),
        p3Housekeeping: _s(j, 'p3_housekeeping'),
        p3Desc: _s(j, 'p3_desc'),
        p4Alat: _s(j, 'p4_alat'),
        p4Desc: _s(j, 'p4_desc'),
        p5Prosedur: _s(j, 'p5_prosedur'),
        p6Desc: _s(j, 'p6_desc'),
        followup: _s(j, 'followup'),
        vlogUrl: _s(j, 'vlog_url'),
        vlogFile: _s(j, 'vlog_file'),
        vlogDesc: _s(j, 'vlog_desc'),
        areaBomak: _s(j, 'area_bomak'),
        jobDesc: _s(j, 'job_desc'),
      );

  bool get p1Ok => p1Doa == 'SUDAH';
  bool get p2Ok => p2Apd == 'SIAP' && p2Stretch == 'SIAP';
  bool get p3Ok => (p3Housekeeping ?? '').startsWith('SESUAI');
  bool get p4Ok => p4Alat == 'SUDAH SESUAI';
  bool get p5Ok => p5Prosedur == 'SUDAH SESUAI PROSEDUR';

  String get temuan =>
      [p3Desc, p4Desc, p6Desc, followup].where((e) => (e ?? '').isNotEmpty).join(' | ');

  String get areaJob =>
      [areaBomak, jobDesc].where((e) => (e ?? '').isNotEmpty).join(' / ');
}

class RibiCoverageRow {
  final String? section;
  final int n;
  final int pekerja;
  final int high;
  final int hari;
  final String? terakhir;

  const RibiCoverageRow({
    this.section,
    this.n = 0,
    this.pekerja = 0,
    this.high = 0,
    this.hari = 0,
    this.terakhir,
  });

  factory RibiCoverageRow.fromJson(Map<String, dynamic> j) => RibiCoverageRow(
        section: j['section']?.toString(),
        n: (j['n'] as num?)?.toInt() ?? 0,
        pekerja: (j['pekerja'] as num?)?.toInt() ?? 0,
        high: (j['high'] as num?)?.toInt() ?? 0,
        hari: (j['hari'] as num?)?.toInt() ?? 0,
        terakhir: j['terakhir']?.toString(),
      );
}

class RibiRow {
  final String tanggal;
  final String? nama;
  final String? nrp;
  final String? jabatan;
  final String? section;
  final String? staffRibi;
  final String? aktivitas;
  final String? lokasi;
  final String? jobDesc;
  final String? bahayaDesc;
  final String? fotoAreaFile;
  final String? fotoJsaFile;
  final String? submittedAt;

  const RibiRow({
    required this.tanggal,
    this.nama,
    this.nrp,
    this.jabatan,
    this.section,
    this.staffRibi,
    this.aktivitas,
    this.lokasi,
    this.jobDesc,
    this.bahayaDesc,
    this.fotoAreaFile,
    this.fotoJsaFile,
    this.submittedAt,
  });

  static String? _s(Map<String, dynamic> j, String k) => j[k]?.toString();

  factory RibiRow.fromJson(Map<String, dynamic> j) => RibiRow(
        tanggal: '${j['tanggal'] ?? ''}',
        nama: _s(j, 'nama'),
        nrp: _s(j, 'nrp'),
        jabatan: _s(j, 'jabatan'),
        section: _s(j, 'section'),
        staffRibi: _s(j, 'staff_ribi'),
        aktivitas: _s(j, 'aktivitas'),
        lokasi: _s(j, 'lokasi'),
        jobDesc: _s(j, 'job_desc'),
        bahayaDesc: _s(j, 'bahaya_desc'),
        fotoAreaFile: _s(j, 'foto_area_file'),
        fotoJsaFile: _s(j, 'foto_jsa_file'),
        submittedAt: _s(j, 'submitted_at'),
      );

  bool get isHighRisk => aktivitas == 'HIGH RISK';

  String get lokasiJob =>
      [lokasi, jobDesc].where((e) => (e ?? '').isNotEmpty).join(' / ');
}

class SyncResult {
  final int fetched;
  final int ok;
  final int fail;
  const SyncResult({this.fetched = 0, this.ok = 0, this.fail = 0});

  factory SyncResult.fromJson(Map<String, dynamic> j) => SyncResult(
        fetched: (j['fetched'] as num?)?.toInt() ?? 0,
        ok: (j['ok'] as num?)?.toInt() ?? 0,
        fail: (j['fail'] as num?)?.toInt() ?? 0,
      );
}

class LatestSync {
  final String? finishedAt;
  final int? okRows;
  const LatestSync({this.finishedAt, this.okRows});

  static LatestSync? fromJson(Map<String, dynamic>? j) {
    if (j == null || j['finished_at'] == null) return null;
    return LatestSync(
      finishedAt: j['finished_at']?.toString(),
      okRows: (j['ok_rows'] as num?)?.toInt(),
    );
  }
}

/// Teks salinan WA Bomak (Safety.tsx copyWA).
String buildBomakWaText({
  required String section,
  required List<Map<String, String?>> rows, // {nama, submittedAt}
  required String syncDate, // dd/MM/yyyy atau ''
}) {
  final lines = <String>[
    'Data Bomak ${section.isEmpty ? 'semua' : section} :',
    for (var i = 0; i < rows.length; i++)
      '${i + 1}. ${(rows[i]['nama'] ?? '-').trim()} - ${waShortDate(rows[i]['submittedAt'])}',
    'Last data update: $syncDate',
  ];
  return lines.join('\n');
}

/// Teks salinan WA R1BI (Ribi.tsx copyWA).
String buildRibiWaText({
  required String section,
  required List<Map<String, String?>> rows, // {nama, tanggal}
  required String syncDate,
}) {
  final lines = <String>[
    'Data R1BI ${section.isEmpty ? 'semua' : section} :',
    for (var i = 0; i < rows.length; i++)
      '${i + 1}. ${(rows[i]['nama'] ?? '-').trim()} - ${waShortDate(rows[i]['tanggal'])}',
    'Last data update: $syncDate',
  ];
  return lines.join('\n');
}
