import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/features/timeline/presentation/timeline_page.dart'
    show
        defaultTimelineFilter,
        timelineDayName,
        timelineDayNum,
        timelineFmtDay,
        timelineMaxDays,
        timelineRangeDates;

void main() {
  group('timelineRangeDates', () {
    test('rentang inklusif dari..to', () {
      final d = timelineRangeDates('2026-11-01', '2026-11-05');
      expect(d, [
        '2026-11-01',
        '2026-11-02',
        '2026-11-03',
        '2026-11-04',
        '2026-11-05',
      ]);
    });

    test('dibatasi timelineMaxDays (31 hari)', () {
      final d = timelineRangeDates('2026-01-01', '2026-12-31');
      expect(d.length, timelineMaxDays);
      expect(d.first, '2026-01-01');
      expect(d.last, '2026-01-31');
    });

    test('melewati batas bulan dengan benar', () {
      final d = timelineRangeDates('2026-02-27', '2026-03-02');
      expect(d, ['2026-02-27', '2026-02-28', '2026-03-01', '2026-03-02']);
    });

    test('tanggal akhir < awal menghasilkan daftar kosong', () {
      expect(timelineRangeDates('2026-11-05', '2026-11-01'), isEmpty);
    });
  });

  group('formatter timeline', () {
    test('timelineFmtDay gaya web fmtDay (Minggu, 1 November 2026)', () {
      // 2026-11-01 jatuh pada hari Minggu.
      expect(timelineFmtDay('2026-11-01'), 'Minggu, 1 November 2026');
      expect(timelineFmtDay('2026-11-05'), 'Kamis, 5 November 2026');
    });

    test('timelineDayName', () {
      expect(timelineDayName('2026-11-01'), 'Minggu');
      expect(timelineDayName('2026-11-06'), 'Jumat');
    });

    test('timelineDayNum dd/M', () {
      expect(timelineDayNum('2026-11-01'), '1/11');
      expect(timelineDayNum('2026-12-25'), '25/12');
    });
  });

  test('defaultTimelineFilter = 7 hari terakhir', () {
    final f = defaultTimelineFilter();
    final df = DateTime.parse(f.df);
    final dt = DateTime.parse(f.dt);
    expect(dt.difference(df).inDays, 6);
    expect(f.crew, '');
    expect(f.cat, '');
  });
}
