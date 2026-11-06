// Model Manpower Inovasi + pengelompokan — kontrak manpower.py + client.ts.
// Manpower Inovasi: snapshot bulanan RptInnovatorMonthly (periode, metrik SS).
// Pengelompokan (manpowermanage): section/crew/status per NRP.

/// Nama bulan singkat gaya web (MANPOWER MONTH_ID).
const List<String> manpowerMonthsId = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agt', 'Sept', 'Okt', 'Nov', 'Des',
];

/// `YYYY-MM` → "Nov 2026" (web fmtPeriode).
String manpowerFmtPeriode(String? p) {
  if (p == null || p.isEmpty) return '-';
  final parts = p.split('-');
  if (parts.length < 2) return p;
  final idx = (int.tryParse(parts[1]) ?? 1) - 1;
  final label = idx >= 0 && idx < manpowerMonthsId.length
      ? manpowerMonthsId[idx]
      : parts[1];
  return '$label ${parts[0]}';
}

/// Satu periode (web ManpowerPeriod).
class ManpowerPeriod {
  final String periode;
  final int manpower;
  final int generalCrew;
  final int assessed;
  final int innovatorSs;
  final int ssClosed;
  final double coveragePct;
  final String? updatedAt;

  const ManpowerPeriod({
    required this.periode,
    this.manpower = 0,
    this.generalCrew = 0,
    this.assessed = 0,
    this.innovatorSs = 0,
    this.ssClosed = 0,
    this.coveragePct = 0,
    this.updatedAt,
  });

  factory ManpowerPeriod.fromJson(Map<String, dynamic> j) => ManpowerPeriod(
        periode: '${j['periode'] ?? ''}',
        manpower: (j['manpower'] as num?)?.toInt() ?? 0,
        generalCrew: (j['general_crew'] as num?)?.toInt() ?? 0,
        assessed: (j['assessed'] as num?)?.toInt() ?? 0,
        innovatorSs: (j['innovator_ss'] as num?)?.toInt() ?? 0,
        ssClosed: (j['ss_closed'] as num?)?.toInt() ?? 0,
        coveragePct: (j['coverage_pct'] as num?)?.toDouble() ?? 0,
        updatedAt: j['updated_at']?.toString(),
      );
}

/// Rincian per dept (web ManpowerDept).
class ManpowerDept {
  final String dept;
  final int manpower;
  final int generalCrew;
  final int assessed;
  final int innovatorSs;
  final double coveragePct;
  final int ssClosed;
  final double ssPerManpower;

  const ManpowerDept({
    required this.dept,
    this.manpower = 0,
    this.generalCrew = 0,
    this.assessed = 0,
    this.innovatorSs = 0,
    this.coveragePct = 0,
    this.ssClosed = 0,
    this.ssPerManpower = 0,
  });

  factory ManpowerDept.fromJson(Map<String, dynamic> j) => ManpowerDept(
        dept: '${j['dept'] ?? ''}',
        manpower: (j['manpower'] as num?)?.toInt() ?? 0,
        generalCrew: (j['general_crew'] as num?)?.toInt() ?? 0,
        assessed: (j['assessed'] as num?)?.toInt() ?? 0,
        innovatorSs: (j['innovator_ss'] as num?)?.toInt() ?? 0,
        coveragePct: (j['coverage_pct'] as num?)?.toDouble() ?? 0,
        ssClosed: (j['ss_closed'] as num?)?.toInt() ?? 0,
        ssPerManpower: (j['ss_per_manpower'] as num?)?.toDouble() ?? 0,
      );
}

/// Ringkasan satu periode (web ManpowerSummary).
class ManpowerSummary {
  final String periode;
  final int manpower;
  final int generalCrew;
  final int assessed;
  final int innovatorSs;
  final int innovatorQcc;
  final int innovatorAll;
  final double coveragePct;
  final int ssClosed;
  final double ssPerManpower;
  final int dtClosed;
  final int qcpClosed;
  final int qccClosed;
  final List<ManpowerDept> dept;

  const ManpowerSummary({
    required this.periode,
    this.manpower = 0,
    this.generalCrew = 0,
    this.assessed = 0,
    this.innovatorSs = 0,
    this.innovatorQcc = 0,
    this.innovatorAll = 0,
    this.coveragePct = 0,
    this.ssClosed = 0,
    this.ssPerManpower = 0,
    this.dtClosed = 0,
    this.qcpClosed = 0,
    this.qccClosed = 0,
    this.dept = const [],
  });

  factory ManpowerSummary.fromJson(Map<String, dynamic> j) => ManpowerSummary(
        periode: '${j['periode'] ?? ''}',
        manpower: (j['manpower'] as num?)?.toInt() ?? 0,
        generalCrew: (j['general_crew'] as num?)?.toInt() ?? 0,
        assessed: (j['assessed'] as num?)?.toInt() ?? 0,
        innovatorSs: (j['innovator_ss'] as num?)?.toInt() ?? 0,
        innovatorQcc: (j['innovator_qcc'] as num?)?.toInt() ?? 0,
        innovatorAll: (j['innovator_all'] as num?)?.toInt() ?? 0,
        coveragePct: (j['coverage_pct'] as num?)?.toDouble() ?? 0,
        ssClosed: (j['ss_closed'] as num?)?.toInt() ?? 0,
        ssPerManpower: (j['ss_per_manpower'] as num?)?.toDouble() ?? 0,
        dtClosed: (j['dt_closed'] as num?)?.toInt() ?? 0,
        qcpClosed: (j['qcp_closed'] as num?)?.toInt() ?? 0,
        qccClosed: (j['qcc_closed'] as num?)?.toInt() ?? 0,
        dept: ((j['dept'] as List? ?? []))
            .map((e) => ManpowerDept.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// Satu baris data manpower (web ManpowerRecord).
class ManpowerRecord {
  final String nrp;
  final String? nama;
  final String? jabatan;
  final String? dept;
  final String? divisi;
  final String? distrik;
  final int ssClosed;
  final int innovatorSs;

  const ManpowerRecord({
    required this.nrp,
    this.nama,
    this.jabatan,
    this.dept,
    this.divisi,
    this.distrik,
    this.ssClosed = 0,
    this.innovatorSs = 0,
  });

  factory ManpowerRecord.fromJson(Map<String, dynamic> j) => ManpowerRecord(
        nrp: '${j['nrp'] ?? ''}',
        nama: j['nama']?.toString(),
        jabatan: j['jabatan']?.toString(),
        dept: j['dept']?.toString(),
        divisi: j['divisi']?.toString(),
        distrik: j['distrik']?.toString(),
        ssClosed: (j['ss_closed'] as num?)?.toInt() ?? 0,
        innovatorSs: (j['innovator_ss'] as num?)?.toInt() ?? 0,
      );
}

/// Halaman data manpower (web ManpowerRecordPage).
class ManpowerRecordPage {
  final int total;
  final int page;
  final int pageSize;
  final List<ManpowerRecord> data;

  const ManpowerRecordPage({
    this.total = 0,
    this.page = 1,
    this.pageSize = 25,
    this.data = const [],
  });

  factory ManpowerRecordPage.fromJson(Map<String, dynamic> j) =>
      ManpowerRecordPage(
        total: (j['total'] as num?)?.toInt() ?? 0,
        page: (j['page'] as num?)?.toInt() ?? 1,
        pageSize: (j['page_size'] as num?)?.toInt() ?? 25,
        data: ((j['data'] as List? ?? []))
            .map((e) => ManpowerRecord.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// Satu kelompok breakdown section/crew/status (web ManpowerBreakdown).
class ManpowerBreakdown {
  final String label;
  final int total;
  final int staff;
  final int mekanik;
  final int repairman;
  final int generalCrew;

  const ManpowerBreakdown({
    required this.label,
    this.total = 0,
    this.staff = 0,
    this.mekanik = 0,
    this.repairman = 0,
    this.generalCrew = 0,
  });

  /// Sisa = total - staff - mekanik - repairman - general_crew.
  int get belum => total - staff - mekanik - repairman - generalCrew;

  factory ManpowerBreakdown.fromJson(Map<String, dynamic> j) =>
      ManpowerBreakdown(
        label: '${j['label'] ?? ''}',
        total: (j['total'] as num?)?.toInt() ?? 0,
        staff: (j['staff'] as num?)?.toInt() ?? 0,
        mekanik: (j['mekanik'] as num?)?.toInt() ?? 0,
        repairman: (j['repairman'] as num?)?.toInt() ?? 0,
        generalCrew: (j['general_crew'] as num?)?.toInt() ?? 0,
      );
}

/// Satu baris profil (web ManpowerProfileRow).
class ManpowerProfileRow {
  final String nrp;
  final String? nama;
  final String? jabatan;
  final String? dept;
  final String? divisi;
  final String? distrik;
  final String? section;
  final String? crew;
  final String? status;
  final bool autoFilled;
  final int ssClosed;
  final int innovatorSs;
  final int innovatorAll;

  const ManpowerProfileRow({
    required this.nrp,
    this.nama,
    this.jabatan,
    this.dept,
    this.divisi,
    this.distrik,
    this.section,
    this.crew,
    this.status,
    this.autoFilled = false,
    this.ssClosed = 0,
    this.innovatorSs = 0,
    this.innovatorAll = 0,
  });

  factory ManpowerProfileRow.fromJson(Map<String, dynamic> j) =>
      ManpowerProfileRow(
        nrp: '${j['nrp'] ?? ''}',
        nama: j['nama']?.toString(),
        jabatan: j['jabatan']?.toString(),
        dept: j['dept']?.toString(),
        divisi: j['divisi']?.toString(),
        distrik: j['distrik']?.toString(),
        section: j['section']?.toString(),
        crew: j['crew']?.toString(),
        status: j['status']?.toString(),
        autoFilled: j['auto_filled'] == true,
        ssClosed: (j['ss_closed'] as num?)?.toInt() ?? 0,
        innovatorSs: (j['innovator_ss'] as num?)?.toInt() ?? 0,
        innovatorAll: (j['innovator_all'] as num?)?.toInt() ?? 0,
      );
}

/// Dashboard pengelompokan (web ManpowerManage).
class ManpowerManage {
  final String? periode;
  final int manpower;
  final int profiled;
  final int classified;
  final int unclassified;
  final int staff;
  final int mekanik;
  final int repairman;
  final int generalCrew;
  final int assessed;
  final List<ManpowerBreakdown> bySection;
  final List<ManpowerBreakdown> byCrew;
  final List<ManpowerBreakdown> byStatus;
  final List<String> sections;
  final List<String> crews;
  final List<String> statuses;
  final List<String> depts;
  final int total;
  final int page;
  final int pageSize;
  final List<ManpowerProfileRow> data;

  const ManpowerManage({
    this.periode,
    this.manpower = 0,
    this.profiled = 0,
    this.classified = 0,
    this.unclassified = 0,
    this.staff = 0,
    this.mekanik = 0,
    this.repairman = 0,
    this.generalCrew = 0,
    this.assessed = 0,
    this.bySection = const [],
    this.byCrew = const [],
    this.byStatus = const [],
    this.sections = const [],
    this.crews = const [],
    this.statuses = const [],
    this.depts = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 25,
    this.data = const [],
  });

  factory ManpowerManage.fromJson(Map<String, dynamic> j) {
    List<ManpowerBreakdown> bl(dynamic v) => ((v as List? ?? []))
        .map((e) => ManpowerBreakdown.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    List<String> sl(dynamic v) =>
        ((v as List? ?? [])).map((e) => '$e').toList();
    return ManpowerManage(
      periode: j['periode']?.toString(),
      manpower: (j['manpower'] as num?)?.toInt() ?? 0,
      profiled: (j['profiled'] as num?)?.toInt() ?? 0,
      classified: (j['classified'] as num?)?.toInt() ?? 0,
      unclassified: (j['unclassified'] as num?)?.toInt() ?? 0,
      staff: (j['staff'] as num?)?.toInt() ?? 0,
      mekanik: (j['mekanik'] as num?)?.toInt() ?? 0,
      repairman: (j['repairman'] as num?)?.toInt() ?? 0,
      generalCrew: (j['general_crew'] as num?)?.toInt() ?? 0,
      assessed: (j['assessed'] as num?)?.toInt() ?? 0,
      bySection: bl(j['by_section']),
      byCrew: bl(j['by_crew']),
      byStatus: bl(j['by_status']),
      sections: sl(j['sections']),
      crews: sl(j['crews']),
      statuses: sl(j['statuses']),
      depts: sl(j['depts']),
      total: (j['total'] as num?)?.toInt() ?? 0,
      page: (j['page'] as num?)?.toInt() ?? 1,
      pageSize: (j['page_size'] as num?)?.toInt() ?? 25,
      data: ((j['data'] as List? ?? []))
          .map((e) =>
              ManpowerProfileRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// Nilai filter "belum diisi" (web EMPTY).
const String manpowerEmpty = '__EMPTY__';
