/// Model Activity — kontrak apps/api/app/api/v1/activities.py + client.ts:324-329.
/// Catatan: list harian memakai kunci `photos` (int) + `cover_id`,
/// rekap memakai `photos_count`, detail memakai `photos` (array).
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
      createdBy: j['created_by']?.toString(),
      photos: photoList,
      photoCount: count,
      coverId: j['cover_id']?.toString(),
    );
  }
}
