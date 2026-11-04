// Model Activity — kontrak apps/api/app/api/v1/activities.py + client.ts:324-329.
// Catatan: list harian memakai kunci `photos` (int) + `cover_id`,
// rekap memakai `photos_count`, detail memakai `photos` (array).

/// Crew baku web (Pages.tsx ACT_CREWS).
const activityCrews = ['Pumping', 'Lighting', 'Mobile', 'Grader', 'PCH'];

/// Kategori baku web (ACT_CATS + "Replace Gland Packing", web 4934628).
const activityCats = [
  'Proker', 'FUI', 'USM', 'SCM',
  'Daily Check Dragflow', 'Washing PLTS', 'Daily Check Waterfill',
  'Replace Gland Packing',
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

  const ActivityPhoto({required this.id, this.origName});

  factory ActivityPhoto.fromJson(Map<String, dynamic> j) => ActivityPhoto(
        id: '${j['id']}',
        origName: j['orig_name']?.toString(),
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
    );
  }
}
