import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/features/activity/data/activity_api.dart';
import 'package:mte_data_center/src/features/activity/domain/activity_models.dart';
import 'package:mte_data_center/src/features/activity/presentation/activity_page.dart'
    show buildCells;

void main() {
  test('by_date memakai kunci photos(int) + cover_id', () {
    final a = Activity.fromJson({
      'id': 'abc',
      'date': '2026-10-05',
      'title': 'Perbaikan pompa',
      'crew': 'Pumping',
      'photos': 3,
      'cover_id': 'p1',
    });
    expect(a.photoCount, 3);
    expect(a.coverId, 'p1');
    expect(a.date, '2026-10-05');
    expect(a.photos, isEmpty);
  });

  test('recap memakai photos_count, detail memakai array photos', () {
    final r = Activity.fromJson({
      'id': 'x',
      'date': '2026-10-05T00:00:00',
      'title': 'T',
      'photos_count': 2,
    });
    expect(r.photoCount, 2);
    expect(r.date, '2026-10-05');

    final d = Activity.fromJson({
      'id': 'y',
      'date': '2026-10-05',
      'title': 'T',
      'photos': [
        {'id': 'p1', 'orig_name': 'a.jpg'},
        {'id': 'p2', 'orig_name': 'b.jpg'},
      ],
    });
    expect(d.photoCount, 2);
    expect(d.photos.map((e) => e.id), ['p1', 'p2']);
  });

  test('photoUrl memakai ?token=', () {
    final u = ActivityApi.photoUrl('aid', 'pid', 'tok123');
    expect(u, endsWith('/v1/activities/aid/photos/pid?token=tok123'));
  });

  test('kalender mulai Senin dan kelipatan 7', () {
    // Okt 2026: 1 Okt = Kamis -> lead 3, 31 hari -> 35 sel? 3+31=34 -> 35.
    final cells = buildCells(2026, 10);
    expect(cells.length % 7, 0);
    expect(cells.first.iso, '2026-09-28'); // Senin sebelum 1 Okt
    expect(cells.where((c) => c.inMonth).length, 31);
  });
}
