/// Model Minute of Meeting — kontrak apps/api/app/api/v1/mom.py.
/// Meeting: judul, tanggal, lokasi, kategori, status open/closed.
/// Item: action item dengan PIC, due date, priority, status, notes.
class MomMeeting {
  final int id;
  final String title;
  final String meetingDate;
  final String? location;
  final String category;
  final String status;
  final String? createdBy;
  final int totalItems;
  final int openItems;

  const MomMeeting({
    required this.id,
    required this.title,
    required this.meetingDate,
    this.location,
    required this.category,
    required this.status,
    this.createdBy,
    this.totalItems = 0,
    this.openItems = 0,
  });

  factory MomMeeting.fromJson(Map<String, dynamic> j) => MomMeeting(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: '${j['title'] ?? ''}',
        meetingDate: '${j['meeting_date'] ?? ''}',
        location: j['location']?.toString(),
        category: '${j['category'] ?? 'Operasional'}',
        status: '${j['status'] ?? 'open'}',
        createdBy: j['created_by']?.toString(),
        totalItems: (j['total_items'] as num?)?.toInt() ?? 0,
        openItems: (j['open_items'] as num?)?.toInt() ?? 0,
      );
}

class MomItem {
  final int id;
  final int meetingId;
  final int itemNo;
  final String description;
  final String? pic;
  final String? dueDate;
  final String priority;
  final String status;
  final String? notes;

  const MomItem({
    required this.id,
    required this.meetingId,
    this.itemNo = 0,
    required this.description,
    this.pic,
    this.dueDate,
    required this.priority,
    required this.status,
    this.notes,
  });

  factory MomItem.fromJson(Map<String, dynamic> j) => MomItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        meetingId: (j['meeting_id'] as num?)?.toInt() ?? 0,
        itemNo: (j['item_no'] as num?)?.toInt() ?? 0,
        description: '${j['description'] ?? ''}',
        pic: j['pic']?.toString(),
        dueDate: j['due_date']?.toString(),
        priority: '${j['priority'] ?? 'medium'}',
        status: '${j['status'] ?? 'open'}',
        notes: j['notes']?.toString(),
      );
}

/// Meeting + items (GET /meetings/{mid}).
class MomMeetingDetail {
  final MomMeeting meeting;
  final List<MomItem> items;
  const MomMeetingDetail({required this.meeting, required this.items});

  factory MomMeetingDetail.fromJson(Map<String, dynamic> j) {
    final m = Map<String, dynamic>.from(j)..remove('items');
    final itemList = (j['items'] as List?) ?? [];
    return MomMeetingDetail(
      meeting: MomMeeting.fromJson(m),
      items: itemList.map((e) => MomItem.fromJson((e as Map).cast<String, dynamic>())).toList(),
    );
  }
}

const momCats = ['Operasional', 'Safety', 'Maintenance', 'Project', 'Lainnya'];
const momPriorities = ['high', 'medium', 'low'];
const momItemStatuses = ['open', 'in_progress', 'closed'];
