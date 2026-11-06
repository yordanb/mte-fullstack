import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/features/manpower/domain/manpower_models.dart';

void main() {
  group('manpowerFmtPeriode', () {
    test('YYYY-MM → "Nov 2026"', () {
      expect(manpowerFmtPeriode('2026-11'), 'Nov 2026');
      expect(manpowerFmtPeriode('2026-01'), 'Jan 2026');
      expect(manpowerFmtPeriode('2026-08'), 'Agt 2026');
      expect(manpowerFmtPeriode('2026-09'), 'Sept 2026');
    });

    test('null/kosong → "-"', () {
      expect(manpowerFmtPeriode(null), '-');
      expect(manpowerFmtPeriode(''), '-');
    });
  });

  group('ManpowerPeriod.fromJson', () {
    test('mem-parse metrik', () {
      final p = ManpowerPeriod.fromJson({
        'periode': '2026-11',
        'manpower': 100,
        'general_crew': 20,
        'assessed': 80,
        'innovator_ss': 30,
        'ss_closed': 45,
        'coverage_pct': 37.5,
      });
      expect(p.periode, '2026-11');
      expect(p.manpower, 100);
      expect(p.generalCrew, 20);
      expect(p.assessed, 80);
      expect(p.innovatorSs, 30);
      expect(p.ssClosed, 45);
      expect(p.coveragePct, 37.5);
    });
  });

  group('ManpowerSummary.fromJson', () {
    test('mem-parse ringkasan + rincian dept', () {
      final s = ManpowerSummary.fromJson({
        'periode': '2026-11',
        'manpower': 100,
        'assessed': 80,
        'innovator_all': 25,
        'innovator_ss': 20,
        'ss_closed': 40,
        'coverage_pct': 25,
        'ss_per_manpower': 0.5,
        'dept': [
          {
            'dept': 'SPL2',
            'manpower': 100,
            'assessed': 80,
            'innovator_ss': 20,
            'coverage_pct': 25,
            'ss_closed': 40,
            'ss_per_manpower': 0.5,
          }
        ],
      });
      expect(s.periode, '2026-11');
      expect(s.innovatorAll, 25);
      expect(s.dept.length, 1);
      expect(s.dept.first.dept, 'SPL2');
      expect(s.dept.first.ssPerManpower, 0.5);
    });

    test('nilai hilang → default 0', () {
      final s = ManpowerSummary.fromJson(const {'periode': '2026-11'});
      expect(s.manpower, 0);
      expect(s.dept, isEmpty);
    });
  });

  group('ManpowerBreakdown', () {
    test('belum = total - staff - mekanik - repairman - general_crew', () {
      const b = ManpowerBreakdown(
        label: 'PCH',
        total: 50,
        staff: 10,
        mekanik: 20,
        repairman: 5,
        generalCrew: 3,
      );
      expect(b.belum, 12);
    });

    test('fromJson', () {
      final b = ManpowerBreakdown.fromJson({
        'label': 'Big Wheel',
        'total': 30,
        'staff': 5,
        'mekanik': 10,
        'repairman': 2,
        'general_crew': 1,
      });
      expect(b.label, 'Big Wheel');
      expect(b.total, 30);
      expect(b.belum, 12);
    });
  });

  group('ManpowerManage.fromJson', () {
    test('mem-parse dasbor + baris profil', () {
      final d = ManpowerManage.fromJson({
        'periode': '2026-11',
        'manpower': 100,
        'classified': 70,
        'unclassified': 30,
        'sections': ['PCH', 'MTE'],
        'crews': ['PCH', 'MTE'],
        'statuses': ['Staff', 'Mekanik'],
        'depts': ['SPL2'],
        'total': 100,
        'page': 1,
        'page_size': 25,
        'by_section': [
          {'label': 'PCH', 'total': 40, 'staff': 5, 'mekanik': 30, 'repairman': 2, 'general_crew': 0}
        ],
        'data': [
          {
            'nrp': '123',
            'nama': 'Budi',
            'section': 'PCH',
            'crew': 'PCH',
            'status': 'Mekanik',
            'auto_filled': true,
            'ss_closed': 3,
          }
        ],
      });
      expect(d.periode, '2026-11');
      expect(d.sections, ['PCH', 'MTE']);
      expect(d.bySection.length, 1);
      expect(d.bySection.first.label, 'PCH');
      expect(d.data.length, 1);
      expect(d.data.first.autoFilled, isTrue);
      expect(d.data.first.ssClosed, 3);
    });

    test('nilai hilang → default aman', () {
      final d = ManpowerManage.fromJson(const {});
      expect(d.periode, isNull);
      expect(d.manpower, 0);
      expect(d.data, isEmpty);
      expect(d.sections, isEmpty);
    });
  });

  group('ManpowerProfileRow.fromJson', () {
    test('mem-parse baris', () {
      final r = ManpowerProfileRow.fromJson({
        'nrp': '999',
        'nama': 'Andi',
        'jabatan': 'MECHANIC',
        'dept': 'SPL2',
        'section': 'MTE',
        'crew': 'MTE',
        'status': 'Mekanik',
        'auto_filled': false,
        'ss_closed': 2,
        'innovator_ss': 1,
        'innovator_all': 1,
      });
      expect(r.nrp, '999');
      expect(r.dept, 'SPL2');
      expect(r.autoFilled, isFalse);
      expect(r.innovatorAll, 1);
    });
  });
}
