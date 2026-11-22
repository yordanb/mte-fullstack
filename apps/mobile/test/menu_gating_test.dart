import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/auth/permissions.dart';
import 'package:mte_data_center/src/core/menu/app_menu.dart';

AuthState _auth({required String role, Map<String, PermActions> perms = const {}}) =>
    AuthState(role: role, permissions: Permissions(perms));

void main() {
  test('admin melihat SEMUA menu (adminOnly ikut)', () {
    final v = visibleMenus(_auth(role: 'admin'));
    expect(v.length, appMenu.length);
    expect(v.map((m) => m.key), containsAll(['users', 'audit', 'prokerponton']));
  });

  test('role biasa: hanya menu ber-izin Lihat yang tampil', () {
    final v = visibleMenus(_auth(role: 'viewer', perms: {
      'dashboard': const PermActions(view: true),
      'equipment': const PermActions(view: true, add: true),
    }));
    expect(v.map((m) => m.key).toList(), ['dashboard', 'equipment']);
  });

  test('izin add/edit tanpa view TIDAK menampilkan menu', () {
    final v = visibleMenus(_auth(role: 'mekanik', perms: {
      'fui': const PermActions(add: true, edit: true),
      'project': const PermActions(edit: true),
    }));
    expect(v, isEmpty);
  });

  test('adminOnly tidak tampil untuk role non-admin walau ada view', () {
    final v = visibleMenus(_auth(role: 'inputer', perms: {
      'users': const PermActions(view: true, add: true),
      'audit': const PermActions(view: true),
    }));
    expect(v.map((m) => m.key), isNot(contains('users')));
    expect(v.map((m) => m.key), isNot(contains('audit')));
  });

  test('semua key menu non-adminOnly ada di MENUS backend (users.py)', () {
    // Daftar MENUS terakhir (V79, 43 item) — key menu mobile harus subset.
    const menus = {
      'dashboard', 'dbr', 'performance', 'activity', 'timeline', 'equipment',
      'fui', 'sugfui', 'fureport', 'project', 'bomak', 'staging', 'mom', 'mom2',
      'riwayat', 'import', 'ppm', 'measurement', 'yazu_lighting',
      'yazudc_lighting', 'yazupumping', 'yazupumpingdc', 'ewacs', 'tarsupport',
      'ss', 'ssab', 'proker', 'prokerbooster', 'prokerinjector', 'manpower',
      'manpowermanage', 'hourmeter', 'prokerthermo', 'prokerpanel',
      'prokerexhaust', 'prokerexhaustmits', 'prokerfandrebb', 'prokerfandpompa',
      'prokergmc', 'prokerfsbooster', 'prokerfsprimer', 'prokerponton',
      'prokersummary',
    };
    for (final m in appMenu) {
      if (m.adminOnly) continue;
      expect(menus, contains(m.key), reason: 'key ${m.key} tak ada di MENUS');
    }
  });

  test('tiap menu non-adminOnly punya rute yang sama dengan app_router', () {
    // Rute yang terdaftar di app_router.dart (path).
    const routes = {
      '/', '/dbr', '/performance', '/timeline', '/activity', '/yazu', '/yazudc',
      '/yazupumping', '/yazupumpingdc', '/bomak', '/equipment', '/staging', '/mom',
      '/mom2', '/riwayat', '/project', '/update-data', '/fui', '/suggestion',
      '/report-followup', '/hourmeter', '/ppm', '/measurement', '/ewacs',
      '/tarsupport', '/proker', '/prokerbooster', '/prokerinjector',
      '/prokerthermo', '/prokerpanel', '/prokerexhaust', '/prokerexhaustmits',
      '/prokerfandrebb', '/prokerfandpompa', '/prokergmc', '/prokerfsbooster',
      '/prokerfsprimer', '/prokerponton', '/ss', '/ssab', '/manpowermanage',
      '/manpower', '/users', '/audit',
    };
    for (final m in appMenu) {
      expect(routes, contains(m.path), reason: 'path ${m.path} tak ada di router');
    }
  });

  test('homePath: admin -> dashboard; role lain -> menu ber-izin pertama', () {
    expect(homePath(_auth(role: 'admin')), '/');
    // Dashboard tanpa izin -> mendarat di menu ber-izin pertama (dbr).
    expect(homePath(_auth(role: 'mekanik', perms: {
      'dbr': const PermActions(view: true),
      'equipment': const PermActions(view: true),
    })), '/dbr');
    // Hanya equipment -> /equipment.
    expect(homePath(_auth(role: 'viewer', perms: {
      'equipment': const PermActions(view: true),
    })), '/equipment');
    // Tanpa menu sama sekali -> fallback '/'.
    expect(homePath(_auth(role: 'viewer')), '/');
  });

  test('menuByPath: path -> entri menu (guard rute per izin)', () {
    expect(menuByPath('/')?.key, 'dashboard');
    expect(menuByPath('/prokerponton')?.key, 'prokerponton');
    expect(menuByPath('/users')?.adminOnly, isTrue);
    expect(menuByPath('/login'), isNull);
    expect(menuByPath('/notifications'), isNull);
  });
}
