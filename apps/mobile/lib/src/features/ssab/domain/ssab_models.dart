// Model SS AB — kontrak apps/api/app/api/v1/ss.py GET /v1/ss/ab +
// apps/web/src/api/client.ts:1307-1368 (SsAbResp). Grade A & B approved
// per tahun, dasar tanggal TANGGAL MENILAI (fallback TANGGAL LAPORAN).

class SsAbKpi {
  final int total;
  final int gradeA;
  final int gradeB;
  final double reward;
  final double manfaat;
  final int pencetus;

  const SsAbKpi({
    required this.total,
    required this.gradeA,
    required this.gradeB,
    required this.reward,
    required this.manfaat,
    required this.pencetus,
  });

  factory SsAbKpi.fromJson(Map<String, dynamic> j) => SsAbKpi(
        total: (j['total'] as num?)?.toInt() ?? 0,
        gradeA: (j['grade_a'] as num?)?.toInt() ?? 0,
        gradeB: (j['grade_b'] as num?)?.toInt() ?? 0,
        reward: (j['reward'] as num?)?.toDouble() ?? 0,
        manfaat: (j['manfaat'] as num?)?.toDouble() ?? 0,
        pencetus: (j['pencetus'] as num?)?.toInt() ?? 0,
      );
}

class SsAbMonth {
  final int month;
  final int total;
  final int a;
  final int b;
  final double reward;

  const SsAbMonth({
    required this.month,
    required this.total,
    required this.a,
    required this.b,
    required this.reward,
  });

  factory SsAbMonth.fromJson(Map<String, dynamic> j) => SsAbMonth(
        month: (j['month'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        a: (j['a'] as num?)?.toInt() ?? 0,
        b: (j['b'] as num?)?.toInt() ?? 0,
        reward: (j['reward'] as num?)?.toDouble() ?? 0,
      );
}

class SsAbDept {
  final String dept;
  final int total;
  final int a;
  final int b;

  const SsAbDept({required this.dept, required this.total, required this.a, required this.b});

  factory SsAbDept.fromJson(Map<String, dynamic> j) => SsAbDept(
        dept: '${j['dept'] ?? ''}',
        total: (j['total'] as num?)?.toInt() ?? 0,
        a: (j['a'] as num?)?.toInt() ?? 0,
        b: (j['b'] as num?)?.toInt() ?? 0,
      );
}

class SsAbRecord {
  final String noSs;
  final String? judul;
  final String? pencetus;
  final String? nrp;
  final String? dept;
  final String? grade;
  final String? kualitas;
  final double reward;
  final double? manfaatFin;
  final String? tglLaporan;
  final String? tglMenilai;
  final String? dinilaiOleh;

  const SsAbRecord({
    required this.noSs,
    this.judul,
    this.pencetus,
    this.nrp,
    this.dept,
    this.grade,
    this.kualitas,
    this.reward = 0,
    this.manfaatFin,
    this.tglLaporan,
    this.tglMenilai,
    this.dinilaiOleh,
  });

  factory SsAbRecord.fromJson(Map<String, dynamic> j) => SsAbRecord(
        noSs: '${j['no_ss'] ?? ''}',
        judul: j['judul']?.toString(),
        pencetus: j['pencetus']?.toString(),
        nrp: j['nrp']?.toString(),
        dept: j['dept']?.toString(),
        grade: j['grade']?.toString(),
        kualitas: j['kualitas']?.toString(),
        reward: (j['reward'] as num?)?.toDouble() ?? 0,
        manfaatFin: (j['manfaat_fin'] as num?)?.toDouble(),
        tglLaporan: j['tgl_laporan']?.toString(),
        tglMenilai: j['tgl_menilai']?.toString(),
        dinilaiOleh: j['dinilai_oleh']?.toString(),
      );
}

class SsAbWaiting {
  final String noSs;
  final String? tglLaporan;
  final String? judul;
  final String? pencetus;
  final String? nrp;
  final String? dept;
  final String? distrik;
  final String? management;
  final String? statusSs;
  final String? outstandingAt;

  const SsAbWaiting({
    required this.noSs,
    this.tglLaporan,
    this.judul,
    this.pencetus,
    this.nrp,
    this.dept,
    this.distrik,
    this.management,
    this.statusSs,
    this.outstandingAt,
  });

  factory SsAbWaiting.fromJson(Map<String, dynamic> j) => SsAbWaiting(
        noSs: '${j['no_ss'] ?? ''}',
        tglLaporan: j['tgl_laporan']?.toString(),
        judul: j['judul']?.toString(),
        pencetus: j['pencetus']?.toString(),
        nrp: j['nrp']?.toString(),
        dept: j['dept']?.toString(),
        distrik: j['distrik']?.toString(),
        management: j['management']?.toString(),
        statusSs: j['status_ss']?.toString(),
        outstandingAt: j['outstanding_at']?.toString(),
      );
}

class SsAbManagerCount {
  final String manager;
  final int total;

  const SsAbManagerCount({required this.manager, required this.total});

  factory SsAbManagerCount.fromJson(Map<String, dynamic> j) => SsAbManagerCount(
        manager: '${j['manager'] ?? ''}',
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}

class SsAbResp {
  final int year;
  final String start;
  final String end;
  final SsAbKpi kpi;
  final List<SsAbMonth> calendar;
  final List<SsAbDept> byDept;
  final List<SsAbRecord> records;
  final List<SsAbWaiting> waiting;
  final List<String> waitingManagers;
  final List<SsAbManagerCount> waitingPerManager;
  final List<int> years;

  const SsAbResp({
    required this.year,
    required this.start,
    required this.end,
    required this.kpi,
    this.calendar = const [],
    this.byDept = const [],
    this.records = const [],
    this.waiting = const [],
    this.waitingManagers = const [],
    this.waitingPerManager = const [],
    this.years = const [],
  });

  factory SsAbResp.fromJson(Map<String, dynamic> j) => SsAbResp(
        year: (j['year'] as num?)?.toInt() ?? 0,
        start: '${j['start'] ?? ''}',
        end: '${j['end'] ?? ''}',
        kpi: SsAbKpi.fromJson(
            (j['kpi'] as Map?)?.cast<String, dynamic>() ?? const {}),
        calendar: ((j['calendar'] as List?) ?? const [])
            .map((e) => SsAbMonth.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        byDept: ((j['by_dept'] as List?) ?? const [])
            .map((e) => SsAbDept.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        records: ((j['records'] as List?) ?? const [])
            .map((e) => SsAbRecord.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        waiting: ((j['waiting'] as List?) ?? const [])
            .map((e) => SsAbWaiting.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        waitingManagers: ((j['waiting_managers'] as List?) ?? const [])
            .map((e) => '$e')
            .toList(),
        waitingPerManager: ((j['waiting_per_manager'] as List?) ?? const [])
            .map((e) =>
                SsAbManagerCount.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        years: ((j['years'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
      );
}
