/// Model Profil + Notifikasi — kontrak users.py: me/password/avatar/
/// notifications + client.ts:67-98.
class NotifImport {
  final String id;
  final String filename;
  final String? sheet;
  final String status;
  final int okRows;
  final int failRows;
  final int totalRows;
  final String? uploadedBy;
  final String? createdAt;

  const NotifImport({
    required this.id,
    required this.filename,
    this.sheet,
    required this.status,
    required this.okRows,
    required this.failRows,
    required this.totalRows,
    this.uploadedBy,
    this.createdAt,
  });

  factory NotifImport.fromJson(Map<String, dynamic> j) => NotifImport(
        id: '${j['id'] ?? ''}',
        filename: '${j['filename'] ?? ''}',
        sheet: j['sheet']?.toString(),
        status: '${j['status'] ?? ''}',
        okRows: (j['ok_rows'] as num?)?.toInt() ?? 0,
        failRows: (j['fail_rows'] as num?)?.toInt() ?? 0,
        totalRows: (j['total_rows'] as num?)?.toInt() ?? 0,
        uploadedBy: j['uploaded_by']?.toString(),
        createdAt: j['created_at']?.toString(),
      );
}

class NotifActivity {
  final String id;
  final String date;
  final String title;
  final String? category;
  final String? cn;
  final String? createdBy;
  final String? createdAt;
  final int photos;

  const NotifActivity({
    required this.id,
    required this.date,
    required this.title,
    this.category,
    this.cn,
    this.createdBy,
    this.createdAt,
    this.photos = 0,
  });

  factory NotifActivity.fromJson(Map<String, dynamic> j) => NotifActivity(
        id: '${j['id'] ?? ''}',
        date: '${j['date'] ?? ''}',
        title: '${j['title'] ?? ''}',
        category: j['category']?.toString(),
        cn: j['cn']?.toString(),
        createdBy: j['created_by']?.toString(),
        createdAt: j['created_at']?.toString(),
        photos: (j['photos'] as num?)?.toInt() ?? 0,
      );
}

class Notifications {
  final List<NotifImport> imports;
  final List<NotifActivity> activities;
  const Notifications({this.imports = const [], this.activities = const []});

  factory Notifications.fromJson(Map<String, dynamic> j) => Notifications(
        imports: ((j['imports'] as List? ?? [])
            .map((e) => NotifImport.fromJson((e as Map).cast<String, dynamic>()))
            .toList()),
        activities: ((j['activities'] as List? ?? [])
            .map((e) => NotifActivity.fromJson((e as Map).cast<String, dynamic>()))
            .toList()),
      );
}
