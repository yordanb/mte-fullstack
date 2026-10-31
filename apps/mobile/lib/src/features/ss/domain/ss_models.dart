/// Model data Suggestion System (SS) untuk Flutter.
class SsKpi {
  final int total;
  final int outstanding;
  final int pending;
  final double reward;
  final double manfaat;
  final int manfaatRows;
  final int pencetus;
  final int gradeAb;
  final int gradeA;
  final int gradeF;

  SsKpi({
    required this.total,
    required this.outstanding,
    required this.pending,
    required this.reward,
    required this.manfaat,
    required this.manfaatRows,
    required this.pencetus,
    required this.gradeAb,
    required this.gradeA,
    required this.gradeF,
  });

  factory SsKpi.fromJson(Map<String, dynamic> json) {
    return SsKpi(
      total: json['total'] ?? 0,
      outstanding: json['outstanding'] ?? 0,
      pending: json['pending'] ?? 0,
      reward: (json['reward'] ?? 0).toDouble(),
      manfaat: (json['manfaat'] ?? 0).toDouble(),
      manfaatRows: json['manfaat_rows'] ?? 0,
      pencetus: json['pencetus'] ?? 0,
      gradeAb: json['grade_ab'] ?? 0,
      gradeA: json['grade_a'] ?? 0,
      gradeF: json['grade_f'] ?? 0,
    );
  }
}

class SsTargetRow {
  final String crew;
  final int target;
  final int aktual;
  final int approved;
  final int menunggu;

  SsTargetRow({
    required this.crew,
    required this.target,
    required this.aktual,
    required this.approved,
    required this.menunggu,
  });

  factory SsTargetRow.fromJson(Map<String, dynamic> json) {
    return SsTargetRow(
      crew: json['crew'] ?? '',
      target: json['target'] ?? 0,
      aktual: json['aktual'] ?? 0,
      approved: json['approved'] ?? 0,
      menunggu: json['menunggu'] ?? 0,
    );
  }
}

class SsOpenApproval {
  final String management;
  final int jumlah;

  SsOpenApproval({required this.management, required this.jumlah});

  factory SsOpenApproval.fromJson(Map<String, dynamic> json) {
    return SsOpenApproval(
      management: json['management'] ?? json['status_ss'] ?? '',
      jumlah: json['jumlah'] ?? 0,
    );
  }
}

class SsTargetCrewResp {
  final int multiplier;
  final int monthCount;
  final int totalTarget;
  final int totalAktual;
  final int approved;
  final int menunggu;
  final List<SsTargetRow> data;
  final List<SsOpenApproval> statusSsBreakdown;
  final String? lastUpdate;

  SsTargetCrewResp({
    required this.multiplier,
    required this.monthCount,
    required this.totalTarget,
    required this.totalAktual,
    required this.approved,
    required this.menunggu,
    required this.data,
    required this.statusSsBreakdown,
    this.lastUpdate,
  });

  factory SsTargetCrewResp.fromJson(Map<String, dynamic> json) {
    var rawList = json['data'] as List? ?? [];
    List<SsTargetRow> rows = rawList.map((e) => SsTargetRow.fromJson(e)).toList();

    var rawBreakdown = json['status_ss_breakdown'] as List? ?? [];
    List<SsOpenApproval> breakdown = rawBreakdown
        .map((e) => SsOpenApproval.fromJson(e))
        .toList();

    return SsTargetCrewResp(
      multiplier: json['multiplier'] ?? 3,
      monthCount: json['month_count'] ?? 1,
      totalTarget: json['total_target'] ?? 0,
      totalAktual: json['total_aktual'] ?? 0,
      approved: json['approved'] ?? 0,
      menunggu: json['menunggu'] ?? 0,
      data: rows,
      statusSsBreakdown: breakdown,
      lastUpdate: json['last_update'],
    );
  }
}

/// Parameter filter Suggestion System.
///
/// Dipakai sebagai family key provider Riverpod, jadi WAJIB punya value
/// equality (`==`/`hashCode`). Kalau memakai `Map<String, dynamic>`, setiap
/// `build()` membuat instance baru dengan identity berbeda sehingga provider
/// terus dibuat ulang dan UI berputar loading tanpa henti.
class SsParams {
  final String dateBasis; // 'laporan' | 'menilai'
  final String? start;
  final String? end;
  final String? dept;
  final String? kategori;
  final String? grade;
  final String? status;
  final String? tahap; // 'outstanding' | 'approved'
  final String? search;

  /// Hanya dipakai endpoint /trend: 'day' | 'month' | 'year'.
  final String granularity;

  const SsParams({
    this.dateBasis = 'menilai',
    this.start,
    this.end,
    this.dept,
    this.kategori,
    this.grade,
    this.status,
    this.tahap,
    this.search,
    this.granularity = 'month',
  });

  SsParams copyWith({String? granularity}) => SsParams(
        dateBasis: dateBasis,
        start: start,
        end: end,
        dept: dept,
        kategori: kategori,
        grade: grade,
        status: status,
        tahap: tahap,
        search: search,
        granularity: granularity ?? this.granularity,
      );

  Map<String, dynamic> toQuery() => {
        'date_basis': dateBasis,
        if (start != null && start!.isNotEmpty) 'start': start,
        if (end != null && end!.isNotEmpty) 'end': end,
        if (dept != null && dept!.isNotEmpty) 'dept': dept,
        if (kategori != null && kategori!.isNotEmpty) 'kategori': kategori,
        if (grade != null && grade!.isNotEmpty) 'grade': grade,
        if (status != null && status!.isNotEmpty) 'status': status,
        if (tahap != null && tahap!.isNotEmpty) 'tahap': tahap,
        if (search != null && search!.isNotEmpty) 'search': search,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SsParams &&
          other.dateBasis == dateBasis &&
          other.start == start &&
          other.end == end &&
          other.dept == dept &&
          other.kategori == kategori &&
          other.grade == grade &&
          other.status == status &&
          other.tahap == tahap &&
          other.search == search &&
          other.granularity == granularity;

  @override
  int get hashCode => Object.hash(dateBasis, start, end, dept, kategori, grade,
      status, tahap, search, granularity);
}

/// Satu titik data /trend: jumlah SS per periode.
class SsTrendPoint {
  final String period;
  final int laporan;
  final int menilai;

  const SsTrendPoint({
    required this.period,
    required this.laporan,
    required this.menilai,
  });

  factory SsTrendPoint.fromJson(Map<String, dynamic> json) => SsTrendPoint(
        period: (json['period'] ?? '').toString(),
        laporan: (json['laporan'] as num?)?.toInt() ?? 0,
        menilai: (json['menilai'] as num?)?.toInt() ?? 0,
      );
}

class SsRecord {
  final int id;
  final String noSs;
  final String? tglLaporan;
  final String? judul;
  final String? pencetus;
  final String? nrp;
  final String? dept;
  final String? grade;
  final String? statusSs;
  final String? management;

  SsRecord({
    required this.id,
    required this.noSs,
    this.tglLaporan,
    this.judul,
    this.pencetus,
    this.nrp,
    this.dept,
    this.grade,
    this.statusSs,
    this.management,
  });

  factory SsRecord.fromJson(Map<String, dynamic> json) {
    return SsRecord(
      id: json['id'] ?? 0,
      noSs: json['no_ss'] ?? '',
      tglLaporan: json['tgl_laporan'],
      judul: json['judul'],
      pencetus: json['pencetus'],
      nrp: json['nrp'],
      dept: json['dept'],
      grade: json['grade'],
      statusSs: json['status_ss'],
      management: json['management'],
    );
  }
}
