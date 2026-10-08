import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/core/utils/date_fmt.dart';
import 'package:mte_data_center/src/features/performance/domain/perf_models.dart';

void main() {
  test('pivot: top 6 prefix + Lainnya, total benar', () {
    final series = [
      for (var i = 1; i <= 8; i++)
        StatsPoint(period: '2026-09-0$i', prefix: 'P$i', n: i * 10),
      const StatsPoint(period: '2026-09-01', prefix: 'P1', n: 5),
    ];
    final piv = pivotSeries(series);
    expect(piv.periods.length, 8);
    expect(piv.bars.length, 7); // 6 + Lainnya
    expect(piv.bars.last, 'Lainnya');
    expect(piv.totals['2026-09-01'], 15); // 10 + 5
  });

  test('pivot tanpa Lainnya bila prefix <= 6', () {
    final piv = pivotSeries([
      const StatsPoint(period: '2026-09-01', prefix: 'TL', n: 3),
      const StatsPoint(period: '2026-09-01', prefix: 'GS', n: 2),
    ]);
    expect(piv.bars, ['TL', 'GS']);
    expect(piv.totals['2026-09-01'], 5);
  });

  test('label periode mengikuti granularitas', () {
    expect(fmtPeriod('2026-07-12T00:00:00', 'day'), '12 Jul 26');
    expect(fmtPeriod('2026-07-07T00:00:00', 'week'), '7 Jul 26');
    expect(fmtPeriod('2026-07-01T00:00:00', 'month'), 'Jul 26');
  });

  test('rata-rata per hari', () {
    expect(const PerfSummary(total: 10, days: 4).avgPerDay, '2.5');
    expect(const PerfSummary().avgPerDay, '-');
  });
}
