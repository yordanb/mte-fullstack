import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/features/dbr/domain/dbr_models.dart';

void main() {
  test('DbrRow: CONTINUE terdeteksi case-insensitive', () {
    final c = DbrRow.fromJson({
      'id': 1,
      'date': '2026-09-01T00:00:00',
      'cn': 'TL960',
      'action': 'Continue',
    });
    expect(c.isContinue, isTrue);
    expect(c.date, '2026-09-01');

    final n = DbrRow.fromJson({'id': 2, 'date': '2026-09-01', 'cn': 'TL960'});
    expect(n.isContinue, isFalse);
    expect(n.code, isNull);
  });

  test('filter client-side seperti web: hanya non-CONTINUE', () {
    final rows = [
      const DbrRow(id: 1, date: '2026-09-01', cn: 'A', action: 'CONTINUE'),
      const DbrRow(id: 2, date: '2026-09-01', cn: 'B', action: 'GANTI OLI'),
      const DbrRow(id: 3, date: '2026-09-01', cn: 'C'),
    ];
    final shown = rows.where((r) => !r.isContinue).toList();
    expect(shown.map((e) => e.id), [2, 3]);
  });
}
