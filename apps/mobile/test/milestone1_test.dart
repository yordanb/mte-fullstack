import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/core/utils/unit_short.dart';
import 'package:mte_data_center/src/core/utils/date_fmt.dart';
import 'package:mte_data_center/src/features/dashboard/data/dashboard_api.dart'
    show LabRow;

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

  test('parameter merah kartu dashboard (grade bukan N)', () {
    final single = LabRow.fromJson({
      'lab_no': '2182152314',
      'vesselid': 'GS1211',
      'unit_id': 'ENGINE',
      'condition': 'CRITICAL',
      'oxi': 39.5,
      'grade_oxi': 'C',
      'tbn': 7.0,
      'grade_tbn': 'N',
    });
    expect(single.redParams, [('OXI', '39.5')]);

    final multi = LabRow.fromJson({
      'lab_no': '2182152314',
      'vesselid': 'GS1211',
      'unit_id': 'ENGINE',
      'condition': 'CRITICAL',
      'oxi': 39.5,
      'grade_oxi': 'A',
      'tbn': 5.0,
      'grade_tbn': 'C',
      'water': 10.0,
      'grade_water': 'C',
      'fe': 20.0,
      'grade_fe': 'N',
    });
    expect(multi.redParams.map((e) => e.$1), ['OXI', 'WTR', 'TBN']);
    expect(multi.redParams.map((e) => e.$2), ['39.5', '10.0', '5.0']);

    final clean =
        LabRow.fromJson({'lab_no': 'X', 'vesselid': 'V', 'unit_id': 'U'});
    expect(clean.redParams, isEmpty);
  });
}
