// Model Activity — kontrak apps/api/app/api/v1/activities.py + client.ts:324-329.
// Catatan: list harian memakai kunci `photos` (int) + `cover_id`,
// rekap memakai `photos_count`, detail memakai `photos` (array).

/// Crew baku web (Pages.tsx ACT_CREWS).
const activityCrews = ['Pumping', 'Lighting', 'Mobile', 'Grader', 'PCH'];

/// Kategori baku web (ACT_CATS, web 4934628).
/// "Replace Gland Packing" dikelola via popup menu di samping DC Dragflow,
/// bukan lewat dropdown kategori.
const activityCats = [
  'Proker', 'FUI', 'USM', 'SCM',
  'Daily Check Dragflow', 'Washing PLTS', 'Daily Check Waterfill',
];

/// Kategori penanda Daily Check Dragflow (auto crew Pumping + opsi Shift).
const dcDragflowCategory = 'Daily Check Dragflow';

/// Pasangan Excavator–Water Pump Daily Check Dragflow (web DRAGFLOW_PAIRS;
/// EX339 = WP1309). Dipakai dropdown CN form + tab DC Dragflow.
const dragflowPairs = [
  ('EX264', 'WP792'),
  ('EX326', 'WP1080'),
  ('EX312', 'WP1081'),
  ('EX265', 'WP791'),
  ('EX339', 'WP1309'),
  ('EX329', 'WP1063'),
];

/// Opsi crew form: daftar baku; crew lama saat ubah di luar daftar ikut
/// disertakan (web ActForm crewOpts).
List<String> crewChoices(String? current) {
  final cur = current?.trim() ?? '';
  if (cur.isEmpty || activityCrews.contains(cur)) return List.of(activityCrews);
  return [...activityCrews, cur];
}

/// Opsi kategori form: bawaan + kategori dari data (`GET /activities/filters`)
/// + kategori lama saat ubah — tanpa ketik manual (web ActForm catChoices).
List<String> catChoices({List<String> fromData = const [], String? current}) {
  final out = <String>{...activityCats, ...fromData.where((e) => e.trim().isNotEmpty)};
  final cur = current?.trim() ?? '';
  if (cur.isNotEmpty && !out.contains(cur)) out.add(cur);
  return out.toList();
}

class ActivityPhoto {
  final String id;
  final String? origName;
  final String? contentType;

  const ActivityPhoto({required this.id, this.origName, this.contentType});

  /// True bila content_type menandakan video (mis. "video/mp4").
  bool get isVideo => (contentType ?? '').toLowerCase().startsWith('video/');

  factory ActivityPhoto.fromJson(Map<String, dynamic> j) => ActivityPhoto(
        id: '${j['id']}',
        origName: j['orig_name']?.toString(),
        contentType: j['content_type']?.toString(),
      );
}

class Activity {
  final String id;
  final String date; // YYYY-MM-DD
  final String title;
  final String? description;
  final String? category;
  final String? crew;
  final String? cn;
  final double? hm;
  final int? shift;
  final String? createdBy;
  final List<ActivityPhoto> photos;
  final int photoCount;
  final String? coverId;
  final bool replaceGlandPacking;
  final String? replaceGlandPackingCn;
  final int? replaceGlandPackingHm;
  final String? replaceGlandPackingDate;

  const Activity({
    required this.id,
    required this.date,
    required this.title,
    this.description,
    this.category,
    this.crew,
    this.cn,
    this.hm,
    this.shift,
    this.createdBy,
    this.photos = const [],
    this.photoCount = 0,
    this.coverId,
    this.replaceGlandPacking = false,
    this.replaceGlandPackingCn,
    this.replaceGlandPackingHm,
    this.replaceGlandPackingDate,
  });

  factory Activity.fromJson(Map<String, dynamic> j) {
    var date = '${j['date'] ?? ''}';
    if (date.length >= 10) date = date.substring(0, 10);
    final photoList = (j['photos'] is List)
        ? (j['photos'] as List)
            .map((e) => ActivityPhoto.fromJson((e as Map).cast<String, dynamic>()))
            .toList()
        : <ActivityPhoto>[];
    final count = (j['photos_count'] as num?)?.toInt() ??
        (j['photos'] is num ? (j['photos'] as num).toInt() : photoList.length);
    return Activity(
      id: '${j['id']}',
      date: date,
      title: '${j['title'] ?? ''}',
      description: j['description']?.toString(),
      category: j['category']?.toString(),
      crew: j['crew']?.toString(),
      cn: j['cn']?.toString(),
      hm: (j['hm'] as num?)?.toDouble(),
      shift: (j['shift'] as num?)?.toInt(),
      createdBy: j['created_by']?.toString(),
      photos: photoList,
      photoCount: count,
      coverId: j['cover_id']?.toString(),
      replaceGlandPacking: j['replace_gland_packing'] as bool? ?? false,
      replaceGlandPackingCn: j['replace_gland_packing_cn']?.toString(),
      replaceGlandPackingHm: j['replace_gland_packing_hm'] as int?,
      replaceGlandPackingDate: j['replace_gland_packing_date']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'title': title,
        'description': description,
        'category': category,
        'crew': crew,
        'cn': cn,
        'hm': hm,
        'shift': shift,
        'created_by': createdBy,
        // photos & photoCount & coverId tidak perlu dikirim ke API
        'replace_gland_packing': replaceGlandPacking,
        'replace_gland_packing_cn': replaceGlandPackingCn,
        'replace_gland_packing_hm': replaceGlandPackingHm,
        'replace_gland_packing_date': replaceGlandPackingDate,
      };
}
