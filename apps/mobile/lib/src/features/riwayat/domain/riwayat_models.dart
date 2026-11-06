// Model Riwayat (Issue Tracking) — kontrak riwayat.py + client.ts.
// Struktur: issue → progress (timeline) → parts (per issue & per progress)
// → foto evidence (per progress & per part).

/// Daftar kategori issue (web CATS).
const List<String> riwayatCats = [
  'Breakdown Unscheduled',
  'Breakdown Scheduled',
  'Maintenance Rutin',
  'Inspection',
  'Modification',
  'Lainnya',
];

/// Status issue + label + warna latar chip (mirip web STATUSES).
class RiwayatStatus {
  final String value;
  final String label;
  const RiwayatStatus(this.value, this.label);
}

const List<RiwayatStatus> riwayatStatuses = [
  RiwayatStatus('open', 'Open'),
  RiwayatStatus('in_progress', 'In Progress'),
  RiwayatStatus('waiting_part', 'Waiting Part'),
  RiwayatStatus('waiting_crew', 'Waiting Crew'),
  RiwayatStatus('closed', 'Closed'),
];

const List<RiwayatStatus> riwayatPartStatuses = [
  RiwayatStatus('needed', 'Needed'),
  RiwayatStatus('ordered', 'Ordered'),
  RiwayatStatus('received', 'Received'),
  RiwayatStatus('installed', 'Installed'),
  RiwayatStatus('cancelled', 'Cancelled'),
];

String riwayatStatusLabel(String v) =>
    riwayatStatuses.firstWhere((s) => s.value == v, orElse: () => RiwayatStatus(v, v)).label;

String riwayatPartStatusLabel(String v) =>
    riwayatPartStatuses.firstWhere((s) => s.value == v, orElse: () => RiwayatStatus(v, v)).label;

/// Satu issue pada daftar.
class RiwayatIssue {
  final int id;
  final String title;
  final String? cn;
  final String category;
  final String status;
  final String startDate;
  final String? endDate;
  final String? description;
  final String? createdBy;
  final int progressCount;
  final int openParts;
  final String? lastProgress;
  final String? lastProgressDate;
  final String? lastProgressBy;

  const RiwayatIssue({
    required this.id,
    required this.title,
    this.cn,
    required this.category,
    required this.status,
    required this.startDate,
    this.endDate,
    this.description,
    this.createdBy,
    this.progressCount = 0,
    this.openParts = 0,
    this.lastProgress,
    this.lastProgressDate,
    this.lastProgressBy,
  });

  factory RiwayatIssue.fromJson(Map<String, dynamic> j) {
    var sd = '${j['start_date'] ?? ''}';
    if (sd.length >= 10) sd = sd.substring(0, 10);
    var ed = j['end_date']?.toString();
    if (ed != null && ed.length >= 10) ed = ed.substring(0, 10);
    return RiwayatIssue(
      id: (j['id'] as num?)?.toInt() ?? 0,
      title: '${j['title'] ?? ''}',
      cn: j['cn']?.toString(),
      category: '${j['category'] ?? ''}',
      status: '${j['status'] ?? 'open'}',
      startDate: sd,
      endDate: ed,
      description: j['description']?.toString(),
      createdBy: j['created_by']?.toString(),
      progressCount: (j['progress_count'] as num?)?.toInt() ?? 0,
      openParts: (j['open_parts'] as num?)?.toInt() ?? 0,
      lastProgress: j['last_progress']?.toString(),
      lastProgressDate: j['last_progress_date']?.toString(),
      lastProgressBy: j['last_progress_by']?.toString(),
    );
  }
}

/// Satu entri progress (timeline).
class RiwayatProgress {
  final int id;
  final int issueId;
  final int seq;
  final String logDate;
  final String description;
  final bool partRequired;
  final String? createdBy;
  final String? createdAt;

  const RiwayatProgress({
    required this.id,
    required this.issueId,
    this.seq = 0,
    required this.logDate,
    required this.description,
    this.partRequired = false,
    this.createdBy,
    this.createdAt,
  });

  factory RiwayatProgress.fromJson(Map<String, dynamic> j) => RiwayatProgress(
        id: (j['id'] as num?)?.toInt() ?? 0,
        issueId: (j['issue_id'] as num?)?.toInt() ?? 0,
        seq: (j['seq'] as num?)?.toInt() ?? 0,
        logDate: '${j['log_date'] ?? ''}',
        description: '${j['description'] ?? ''}',
        partRequired: j['part_required'] == true,
        createdBy: j['created_by']?.toString(),
        createdAt: j['created_at']?.toString(),
      );
}

/// Satu part (per issue).
class RiwayatPart {
  final int id;
  final int issueId;
  final String partName;
  final int qty;
  final String status;
  final String? eta;
  final String? notes;
  final String? createdAt;

  const RiwayatPart({
    required this.id,
    required this.issueId,
    required this.partName,
    this.qty = 1,
    this.status = 'needed',
    this.eta,
    this.notes,
    this.createdAt,
  });

  factory RiwayatPart.fromJson(Map<String, dynamic> j) => RiwayatPart(
        id: (j['id'] as num?)?.toInt() ?? 0,
        issueId: (j['issue_id'] as num?)?.toInt() ?? 0,
        partName: '${j['part_name'] ?? ''}',
        qty: (j['qty'] as num?)?.toInt() ?? 1,
        status: '${j['status'] ?? 'needed'}',
        eta: j['eta']?.toString(),
        notes: j['notes']?.toString(),
        createdAt: j['created_at']?.toString(),
      );
}

/// Detail issue lengkap (issue + progress + parts).
class RiwayatIssueFull {
  final RiwayatIssue issue;
  final List<RiwayatProgress> progress;
  final List<RiwayatPart> parts;

  const RiwayatIssueFull({
    required this.issue,
    this.progress = const [],
    this.parts = const [],
  });

  factory RiwayatIssueFull.fromJson(Map<String, dynamic> j) => RiwayatIssueFull(
        issue: RiwayatIssue.fromJson(j),
        progress: ((j['progress'] as List? ?? []))
            .map((e) =>
                RiwayatProgress.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        parts: ((j['parts'] as List? ?? []))
            .map((e) => RiwayatPart.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// Foto/file evidence (dipakai progress & part).
class RiwayatPhoto {
  final int id;
  final String origName;
  final String? contentType;
  final int size;
  final String? notes;

  const RiwayatPhoto({
    required this.id,
    required this.origName,
    this.contentType,
    this.size = 0,
    this.notes,
  });

  bool get isImage => (contentType ?? '').toLowerCase().startsWith('image/');

  factory RiwayatPhoto.fromJson(Map<String, dynamic> j) => RiwayatPhoto(
        id: (j['id'] as num?)?.toInt() ?? 0,
        origName: '${j['orig_name'] ?? ''}',
        contentType: j['content_type']?.toString(),
        size: (j['size'] as num?)?.toInt() ?? 0,
        notes: j['notes']?.toString(),
      );
}
