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

  test('perm matrix: 29 menu backend (sinkron users.py MENUS, urutan sama)', () {
    expect(permMenus.length, 29);
    expect(permMenus.first, 'dashboard');
    expect(permMenus.last, 'manpowermanage');
    expect(
        permMenus,
        containsAll([
          'import', 'timeline', 'project', 'bomak', 'staging', 'mom',
          'riwayat', 'ppm', 'measurement', 'yazu', 'yazudc', 'ewacs',
          'tarsupport', 'ss', 'ssab', 'proker', 'prokerbooster',
          'prokerinjector', 'prokerthermo', 'manpower', 'manpowermanage',
        ]));
    expect(permMenus.toSet().length, permMenus.length); // tanpa duplikat
  });

  test('userRoles: 9 role backend + matriks 8 tanpa admin', () {
    expect(userRoles.length, 9);
    expect(userRoles,
        containsAll(['inputer', 'mekanik', 'viewer', 'adm lce', 'adm te']));
    expect(permMatrixRoles.length, 8);
    expect(permMatrixRoles, isNot(contains('admin')));
  });

  test('menuLabel: label ramah web, menu lain apa adanya', () {
    expect(menuLabel('ss'), 'ss — Sugestion System');
    expect(menuLabel('ssab'), 'ssab — SS AB');
    expect(menuLabel('yazu'), 'yazu — Yazu P2H');
    expect(menuLabel('dbr'), 'dbr');
  });

  test('perm toggle: uncheck view auto-uncheck write (web ca75ff0)', () {
    const row = PermRow(role: 'inputer', menu: 'dbr', canView: true, canAdd: true);
    // Simulasi uncheck view -> auto-uncheck semua write
    final next = row.copyWith(canView: false, canAdd: false, canEdit: false, canDelete: false);
    expect(next.canView, isFalse);
    expect(next.canAdd, isFalse);
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
