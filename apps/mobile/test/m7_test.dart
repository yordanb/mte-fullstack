import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/features/profile/domain/profile_models.dart';
import 'package:mte_data_center/src/features/update_data/domain/import_models.dart';
import 'package:mte_data_center/src/features/users/domain/user_models.dart';

void main() {
  test('dry-run: ok/fail + errors + preview', () {
    final r = DryRunResult.fromJson({
      'total': 148,
      'ok': 0,
      'fail': 148,
      'errors': [
        {'row': 2, 'error': "'DATE'"}
      ],
      'preview': [],
    });
    expect(r.total, 148);
    expect(r.fail, 148);
    expect(r.errors.first.row, 2);
  });

  test('perm matrix: 10 menu dikenal', () {
    expect(permMenus.length, 10);
    expect(permMenus, contains('import'));
  });

  test('perm toggle butuh view bila tulis (aturan server)', () {
    const row = PermRow(role: 'inputer', menu: 'dbr', canAdd: true);
    final violates =
        (row.canAdd || row.canEdit || row.canDelete) && !row.canView;
    expect(violates, isTrue);
  });

  test('notifikasi: imports + activities', () {
    final n = Notifications.fromJson({
      'imports': [
        {'id': '1', 'filename': 'f.xlsx', 'status': 'COMMITTED', 'ok_rows': 5}
      ],
      'activities': [
        {'id': 'a', 'date': '2026-10-01', 'title': 'T'}
      ],
    });
    expect(n.imports.first.status, 'COMMITTED');
    expect(n.activities.first.title, 'T');
  });
}
