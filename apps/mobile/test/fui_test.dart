import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/features/fui/domain/fui_models.dart';

OilRow _row(String vessel, String unit, [String cond = 'CRITICAL']) => OilRow(
      labNo: '$vessel-$unit',
      vesselId: vessel,
      unitId: unit,
      condition: cond,
    );

void main() {
  test('grouping konsekutif per vessel/unit', () {
    final groups = groupSuggestions([
      _row('TL1', 'ENGINE'),
      _row('TL1', 'ENGINE'),
      _row('TL1', 'HYDRAULIC'),
      _row('GS2', 'ENGINE'),
    ]);
    expect(groups.map((g) => g.key),
        ['TL1 / ENGINE', 'TL1 / HYDRAULIC', 'GS2 / ENGINE']);
    expect(groups.first.rows.length, 2);
  });

  test('grade bukan N ditandai merah', () {
    final r = OilRow.fromJson({
      'lab_no': 'L1',
      'vesselid': 'V',
      'unit_id': 'U',
      'fe': 22.5,
      'grade_fe': 'C',
      'visc': 14.0,
      'grade_visc': 'N',
    });
    expect(r.badGrade('fe'), isTrue);
    expect(r.badGrade('visc'), isFalse);
    expect(r.badGrade('cu'), isFalse);
  });

  test('report row: type/product + badge count', () {
    final r = SuggestReportRow.fromJson({
      'lab_no': 'L1',
      'vesselid': 'V',
      'unit_id': 'U',
      'sample_date': '2026-09-01T00:00:00',
      'condition': 'WARNING',
      'unit_type': 'T',
      'suggest_count': 2,
      'latest_suggestion': 'Ganti oli',
    });
    expect(r.typeProduct, 'T');
    expect(r.suggestCount, 2);
    expect(r.sampleDate, '2026-09-01');
  });
}
