/// Model MOM 2 (MOM Meeting Weekly SPEX Pumping) — kontrak apps/api/app/api/v1/mom2.py.
/// Semua fromJson toleran terhadap field kosong/hilang.
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
int? _iOrNull(Object? v) => (v as num?)?.toInt();

String? _s(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// Baris daftar meeting (GET /v1/mom2/meetings — data m.* + hitungan item).
class Mom2Meeting {
  final int id;
  final String period;
  final int? week;
  final String? meetingDate;
  final String? participants;
  final String status;
  final String? createdBy;
  final int totalItems;
  final int openItems;

  const Mom2Meeting({
    required this.id,
    this.period = '',
    this.week,
    this.meetingDate,
    this.participants,
    this.status = 'open',
    this.createdBy,
    this.totalItems = 0,
    this.openItems = 0,
  });

  factory Mom2Meeting.fromJson(Map<String, dynamic> j) => Mom2Meeting(
        id: _i(j['id']),
        period: '${j['period'] ?? ''}',
        week: _iOrNull(j['week']),
        meetingDate: _s(j['meeting_date']),
        participants: _s(j['participants']),
        status: '${j['status'] ?? 'open'}',
        createdBy: _s(j['created_by']),
        totalItems: _i(j['total_items']),
        openItems: _i(j['open_items']),
      );

  /// Status open/closed memengaruhi warna kartu.
  bool get isOpen => status == 'open';
}

/// Item meeting (tabel mom2_items).
class Mom2Item {
  final int id;
  final int meetingId;
  final int? seq;
  final String? topic;
  final String description;
  final String? reporter;
  final String? pic;
  final String? dueDate;
  final bool dueFlex;
  final String? dueText;
  final String status;
  final String? remark;

  const Mom2Item({
    required this.id,
    this.meetingId = 0,
    this.seq,
    this.topic,
    this.description = '',
    this.reporter,
    this.pic,
    this.dueDate,
    this.dueFlex = false,
    this.dueText,
    this.status = 'open',
    this.remark,
  });

  factory Mom2Item.fromJson(Map<String, dynamic> j) => Mom2Item(
        id: _i(j['id']),
        meetingId: _i(j['meeting_id']),
        seq: _iOrNull(j['seq']),
        topic: _s(j['topic']),
        description: '${j['description'] ?? ''}',
        reporter: _s(j['reporter']),
        pic: _s(j['pic']),
        dueDate: _s(j['due_date']),
        dueFlex: j['due_flex'] == true,
        dueText: _s(j['due_text']),
        status: '${j['status'] ?? 'open'}',
        remark: _s(j['remark']),
      );

  /// Due date tampil: teks fleksibel bila ambigu (perilaku web export).
  String? get dueDisplay => dueFlex ? (dueText ?? dueDate) : dueDate;
}

/// Balasan GET /v1/mom2/meetings/{id} — meeting + items.
class Mom2MeetingDetail {
  final Mom2Meeting meeting;
  final List<Mom2Item> items;

  const Mom2MeetingDetail({required this.meeting, this.items = const []});

  factory Mom2MeetingDetail.fromJson(Map<String, dynamic> j) =>
      Mom2MeetingDetail(
        meeting: Mom2Meeting.fromJson(j),
        items: [
          for (final e in (j['items'] as List? ?? const []))
            Mom2Item.fromJson((e as Map).cast<String, dynamic>()),
        ],
      );
}
