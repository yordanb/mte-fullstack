import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/core/utils/unit_short.dart';
import 'package:mte_data_center/src/core/utils/date_fmt.dart';

void main() {
  test('shortUnit meniru web Widgets.tsx', () {
    expect(shortUnit('FINAL DRIVE LEFT'), 'FD LH');
    expect(shortUnit('final drive right front'), 'FD RH FR');
    expect(shortUnit('DIFFERENTIAL CENTER'), 'DIFF CTR');
    expect(shortUnit('TRANSMISSION'), 'TM');
    expect(shortUnit('HYDRAULIC PUMP'), 'HYDRAULIC PUMP');
  });

  test('format tanggal sesuai handoff §6', () {
    expect(toApiDate(DateTime(2026, 7, 5)), '2026-07-05');
    expect(fmtDdbr('2026-07-12T00:00:00+00:00'), contains('Jul'));
    expect(fmtDate('2026-07-12T00:00:00+00:00'), contains('/07/2026'));
    expect(fmtDT('2026-07-12T10:30:00+00:00'), contains('12/07/2026'));
  });
}
