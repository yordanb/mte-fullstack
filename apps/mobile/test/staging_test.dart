import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/features/staging/domain/staging_models.dart';

void main() {
  group('stagingCurPeriod', () {
    test('format YYYY-MM dari tanggal lokal', () {
      expect(stagingCurPeriod(DateTime(2026, 11, 6)), '2026-11');
      expect(stagingCurPeriod(DateTime(2026, 1, 31)), '2026-01');
    });
  });

  group('stagingShiftPeriod', () {
    test('mundur satu bulan', () {
      expect(stagingShiftPeriod('2026-11', -1), '2026-10');
    });

    test('maju melewati batas tahun', () {
      expect(stagingShiftPeriod('2026-12', 1), '2027-01');
    });

    test('mundur melewati batas tahun', () {
      expect(stagingShiftPeriod('2026-01', -1), '2025-12');
    });

    test('geser beberapa bulan sekaligus', () {
      expect(stagingShiftPeriod('2026-05', 8), '2027-01');
    });
  });

  group('stagingPeriodLabel', () {
    test('nama bulan panjang + tahun', () {
      expect(stagingPeriodLabel('2026-11'), 'November 2026');
      expect(stagingPeriodLabel('2026-01'), 'Januari 2026');
      expect(stagingPeriodLabel('2026-08'), 'Agustus 2026');
    });
  });

  group('stagingRoleLabel', () {
    test('0 = Primer, lain = Booster n', () {
      expect(stagingRoleLabel(0), 'Primer');
      expect(stagingRoleLabel(1), 'Booster 1');
      expect(stagingRoleLabel(6), 'Booster 6');
    });
  });

  group('stagingRoleColor', () {
    test('kembalikan warna berbeda per role dan fallback aman', () {
      expect(stagingRoleColor(0), isNot(stagingRoleColor(1)));
      expect(stagingRoleColor(99), stagingRoleColor(6));
    });
  });

  group('stagingParseQuickGroup', () {
    test('parse format web "Sump C3 [Transfer] - WP1 - WP2"', () {
      final r = stagingParseQuickGroup('Sump C3 [Transfer] - WP764 - WP1126');
      expect(r, isNotNull);
      expect(r!.sump, 'Sump C3');
      expect(r.system, 'Transfer');
      expect(r.cn, ['WP764', 'WP1126']);
    });

    test('menerima koma dan newline sebagai pemisah', () {
      final r = stagingParseQuickGroup('SUMP D1 [SARABAKAWA]\nWP1, WP2\nWP3');
      expect(r, isNotNull);
      expect(r!.cn, ['WP1', 'WP2', 'WP3']);
    });

    test('normalisasi CN ke huruf besar tanpa spasi', () {
      final r = stagingParseQuickGroup('Sump X[Sistem] - wp 1 - Wp2');
      expect(r!.cn, ['WP1', 'WP2']);
    });

    test('null bila format tidak valid', () {
      expect(stagingParseQuickGroup('tanpa kurung siku'), isNull);
      expect(stagingParseQuickGroup('Sump [Sistem]'), isNull);
      expect(stagingParseQuickGroup(''), isNull);
    });
  });

  group('stagingParseChain', () {
    test('pecah CN unik dan naikkan ke huruf besar', () {
      expect(stagingParseChain('wp1 - WP2 - wp1'), ['WP1', 'WP2']);
    });

    test('abaikan segmen kosong', () {
      expect(stagingParseChain('WP1 -- WP2 -'), ['WP1', 'WP2']);
    });
  });

  group('StagingGroup', () {
    test('fromJson mem-parse grup + pump', () {
      final g = StagingGroup.fromJson({
        'id': 5,
        'group_no': 2,
        'sump_name': 'SUMP\nD1',
        'system_type': 'Transfer',
        'is_active': true,
        'pumps': [
          {
            'id': 10,
            'pump_cn': 'WP764',
            'role_order': 0,
            'role_label': 'Primer',
            'unit_type': 'Pump',
          }
        ],
      });
      expect(g.id, 5);
      expect(g.groupNo, 2);
      expect(g.sumpClean, 'SUMP D1');
      expect(g.isActive, isTrue);
      expect(g.pumps.length, 1);
      expect(g.pumps.first.pumpCn, 'WP764');
      expect(g.pumps.first.roleLabel, 'Primer');
    });

    test('pumps kosong bila tidak ada', () {
      final g = StagingGroup.fromJson(
          const {'id': 1, 'group_no': 1, 'system_type': 'X'});
      expect(g.pumps, isEmpty);
      expect(g.isActive, isTrue);
      expect(g.sumpClean, '');
    });
  });

  group('StagingPump', () {
    test('roleLabel fallback dari role_order bila kosong', () {
      final p = StagingPump.fromJson(const {'id': 1, 'pump_cn': 'WP1', 'role_order': 2});
      expect(p.roleLabel, 'Booster 2');
    });
  });

  group('StagingChange', () {
    test('fromJson mem-parse perubahan', () {
      final c = StagingChange.fromJson({
        'id': 1,
        'group_id': 3,
        'period': '2026-11',
        'change_type': 'MOVE',
        'pump_cn': 'WP1',
        'from_value': 'Grup 1',
        'to_value': 'Grup 2',
        'changed_by': 'budi',
        'changed_at': '2026-11-06T10:00:00',
        'group_no': 2,
      });
      expect(c.changeType, 'MOVE');
      expect(c.pumpCn, 'WP1');
      expect(c.toValue, 'Grup 2');
      expect(c.changedBy, 'budi');
      expect(c.groupNo, 2);
    });
  });
}
