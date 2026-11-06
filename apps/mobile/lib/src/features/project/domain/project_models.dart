// Model Project (Project Management) — kontrak projects.py + client.ts.
// Struktur: project → stages (tahapan) → updates (progress) → photo_list.

/// Label status tahap/project (web ST_LABEL).
const Map<String, String> projStLabel = {
  'BELUM_MULAI': 'Belum Mulai',
  'ON_TRACK': 'On Track',
  'AT_RISK': 'At Risk',
  'TERLAMBAT': 'Terlambat',
  'SELESAI': 'Selesai',
};

/// Urutan pilihan status pada form update (web UpdateForm).
const List<String> projUpdateStatuses = [
  'BELUM_MULAI',
  'ON_TRACK',
  'AT_RISK',
  'SELESAI',
];

/// Daftar crew yang disarankan (web CREWS).
const List<String> projCrews = ['Pumping', 'Lighting', 'Mobile', 'Grader', 'PCH'];

String projStatusLabel(String v) => projStLabel[v] ?? v;

/// Satu foto eviden update (web photo_list item).
class ProjPhoto {
  final String id;
  final String? origName;
  const ProjPhoto({required this.id, this.origName});

  factory ProjPhoto.fromJson(Map<String, dynamic> j) => ProjPhoto(
        id: '${j['id'] ?? ''}',
        origName: j['orig_name']?.toString(),
      );
}

/// Satu update progress tahap.
class ProjUpdate {
  final String id;
  final String date;
  final int progress;
  final String status;
  final String? note;
  final String? createdBy;
  final int photos;
  final List<ProjPhoto> photoList;

  const ProjUpdate({
    required this.id,
    required this.date,
    this.progress = 0,
    this.status = 'ON_TRACK',
    this.note,
    this.createdBy,
    this.photos = 0,
    this.photoList = const [],
  });

  factory ProjUpdate.fromJson(Map<String, dynamic> j) => ProjUpdate(
        id: '${j['id'] ?? ''}',
        date: '${j['date'] ?? ''}',
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        status: '${j['status'] ?? 'ON_TRACK'}',
        note: j['note']?.toString(),
        createdBy: j['created_by']?.toString(),
        photos: (j['photos'] as num?)?.toInt() ?? 0,
        photoList: ((j['photo_list'] as List? ?? []))
            .map((e) => ProjPhoto.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// Satu tahapan (stage) project.
class ProjStage {
  final String id;
  final String name;
  final String? planStart;
  final String? planEnd;
  final double? weight;
  final int progress;
  final String derived;
  final ProjUpdate? latest;
  final List<ProjUpdate> updates;

  const ProjStage({
    required this.id,
    required this.name,
    this.planStart,
    this.planEnd,
    this.weight,
    this.progress = 0,
    this.derived = 'BELUM_MULAI',
    this.latest,
    this.updates = const [],
  });

  factory ProjStage.fromJson(Map<String, dynamic> j) {
    String? cut(dynamic v) {
      if (v == null) return null;
      var s = '$v';
      if (s.length >= 10) s = s.substring(0, 10);
      return s.isEmpty ? null : s;
    }

    return ProjStage(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? ''}',
      planStart: cut(j['plan_start']),
      planEnd: cut(j['plan_end']),
      weight: (j['weight'] as num?)?.toDouble(),
      progress: (j['progress'] as num?)?.toInt() ?? 0,
      derived: '${j['derived'] ?? 'BELUM_MULAI'}',
      latest: j['latest'] == null
          ? null
          : ProjUpdate.fromJson((j['latest'] as Map).cast<String, dynamic>()),
      updates: ((j['updates'] as List? ?? []))
          .map((e) => ProjUpdate.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// Satu project (daftar & detail).
class Project {
  final String id;
  final String name;
  final String? description;
  final String? pic;
  final String? cn;
  final String? crew;
  final String? targetDate;
  final int progress;
  final String derived;
  final int nstage;
  final List<ProjStage> stages;

  const Project({
    required this.id,
    required this.name,
    this.description,
    this.pic,
    this.cn,
    this.crew,
    this.targetDate,
    this.progress = 0,
    this.derived = 'BELUM_MULAI',
    this.nstage = 0,
    this.stages = const [],
  });

  factory Project.fromJson(Map<String, dynamic> j) {
    String? cut(dynamic v) {
      if (v == null) return null;
      var s = '$v';
      if (s.length >= 10) s = s.substring(0, 10);
      return s.isEmpty ? null : s;
    }

    return Project(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? ''}',
      description: j['description']?.toString(),
      pic: j['pic']?.toString(),
      cn: j['cn']?.toString(),
      crew: j['crew']?.toString(),
      targetDate: cut(j['target_date']),
      progress: (j['progress'] as num?)?.toInt() ?? 0,
      derived: '${j['derived'] ?? 'BELUM_MULAI'}',
      nstage: (j['nstage'] as num?)?.toInt() ?? 0,
      stages: ((j['stages'] as List? ?? []))
          .map((e) => ProjStage.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// Hasil halaman daftar project.
class ProjectPage {
  final int total;
  final int page;
  final int pageSize;
  final List<Project> data;

  const ProjectPage({
    required this.total,
    required this.page,
    this.pageSize = 20,
    this.data = const [],
  });

  factory ProjectPage.fromJson(Map<String, dynamic> j) => ProjectPage(
        total: (j['total'] as num?)?.toInt() ?? 0,
        page: (j['page'] as num?)?.toInt() ?? 1,
        pageSize: (j['page_size'] as num?)?.toInt() ?? 20,
        data: ((j['data'] as List? ?? []))
            .map((e) => Project.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
