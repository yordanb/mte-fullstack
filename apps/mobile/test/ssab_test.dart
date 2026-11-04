import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/features/ssab/domain/ssab_models.dart';
import 'package:mte_data_center/src/features/ssab/presentation/ssab_page.dart'
    show filterWaitingByManager, fmtDateDash, fmtNum, fmtRpShort, managerChipLabel,
        monthLabel, titleName;

void main() {
  final payload = {
    'year': 2026,
    'start': '2026-01-01',
    'end': '2026-11-04',
    'kpi': {
      'total': 10,
      'grade_a': 4,
      'grade_b': 6,
      'reward': 12500000.0,
      'manfaat': 2500000000.0,
      'pencetus': 5,
    },
    'calendar': [
      for (var m = 1; m <= 12; m++)
        {
          'month': m,
          'total': m <= 3 ? m : 0,
          'a': m <= 3 ? 1 : 0,
          'b': m <= 3 ? m - 1 : 0,
          'reward': m <= 3 ? 1000000.0 : 0.0,
        },
    ],
    'by_dept': [
      {'dept': 'Pumping', 'total': 6, 'a': 2, 'b': 4},
      {'dept': '(kosong)', 'total': 4, 'a': 2, 'b': 2},
    ],
    'records': [
      {
        'no_ss': 'SS-001',
        'judul': 'Ide perbaikan',
        'pencetus': 'budi santoso',
        'nrp': '12345',
        'dept': 'Pumping',
        'grade': 'A',
        'kualitas': 'Baik',
        'reward': 5000000,
        'manfaat_fin': 1000000,
        'tgl_laporan': '2026-02-01',
        'tgl_menilai': '2026-03-01',
        'dinilai_oleh': 'adi nugroho',
      },
    ],
    'waiting': [
      {
        'no_ss': 'SS-002',
        'tgl_laporan': '2026-10-01',
        'judul': 'Waiting',
        'pencetus': 'ana',
        'nrp': '999',
        'dept': 'Pumping',
        'distrik': 'X',
        'management': 'Rachmad Rizky Nur Fabiyanto',
        'status_ss': 'Menunggu Penilaian oleh PM',
        'outstanding_at': '2026-10-10',
      },
    ],
    'waiting_managers': ['Rachmad Rizky Nur Fabiyanto', 'Gunarto'],
    'waiting_per_manager': [
      {'manager': 'Rachmad Rizky Nur Fabiyanto', 'total': 1},
      {'manager': 'Gunarto', 'total': 0},
    ],
    'years': [2026, 2025],
  };

  test('SsAbResp.fromJson mem-parse kpi/kalender/dept/records/waiting', () {
    final r = SsAbResp.fromJson(Map<String, dynamic>.from(payload));
    expect(r.year, 2026);
    expect(r.kpi.gradeA, 4);
    expect(r.kpi.gradeB, 6);
    expect(r.kpi.reward, 12500000.0);
    expect(r.calendar.length, 12);
    expect(r.calendar[0].month, 1);
    expect(r.calendar[0].total, 1);
    expect(r.byDept.first.dept, 'Pumping');
    expect(r.records.first.noSs, 'SS-001');
    expect(r.records.first.grade, 'A');
    expect(r.records.first.manfaatFin, 1000000.0);
    expect(r.waiting.first.statusSs, contains('PM'));
    expect(r.waiting.first.outstandingAt, '2026-10-10');
    expect(r.waitingManagers, hasLength(2));
    expect(r.waitingPerManager.first.total, 1);
    expect(r.years, [2026, 2025]);
  });

  test('SsAbResp.fromJson toleran payload kosong', () {
    final r = SsAbResp.fromJson(const {});
    expect(r.kpi.total, 0);
    expect(r.calendar, isEmpty);
    expect(r.records, isEmpty);
    expect(r.waiting, isEmpty);
    expect(r.years, isEmpty);
  });

  test('fmtRpShort mengikuti ambang web (T/M/jt/rb)', () {
    expect(fmtRpShort(999), 'Rp 999');
    expect(fmtRpShort(3000), 'Rp 3 rb');
    expect(fmtRpShort(12500000), 'Rp 12,5 jt');
    expect(fmtRpShort(2500000000), 'Rp 2,50 M');
    expect(fmtRpShort(1500000000000), 'Rp 1,50 T');
    expect(fmtRpShort(null), 'Rp 0');
  });

  test('fmtNum & fmtDateDash gaya halaman web', () {
    expect(fmtNum(1234567), '1.234.567');
    expect(fmtDateDash(null), '-');
    expect(fmtDateDash('2026-03-01'), '01/03/2026');
  });

  test('titleName Title Case per kata (web titleName)', () {
    expect(titleName('budi santoso'), 'Budi Santoso');
    expect(titleName('rachmad RIZKY nur'), 'Rachmad Rizky Nur');
    expect(titleName('a-b c'), 'A-B C');
    expect(titleName(null), '');
  });

  test('monthLabel 12 bulan Indonesia', () {
    expect(monthLabel(1), 'Januari');
    expect(monthLabel(11), 'November');
    expect(monthLabel(12), 'Desember');
  });

  test('filterWaitingByManager: substring tanpa peduli besar-kecil', () {
    final rows = [
      const SsAbWaiting(noSs: '1', management: 'Rachmad Rizky Nur Fabiyanto'),
      const SsAbWaiting(noSs: '2', management: 'Gunarto'),
      const SsAbWaiting(noSs: '3', management: null),
    ];
    expect(filterWaitingByManager(rows, ''), hasLength(3));
    expect(filterWaitingByManager(rows, 'rachmad'), hasLength(1));
    expect(filterWaitingByManager(rows, 'GUNARTO').single.noSs, '2');
    expect(filterWaitingByManager(rows, 'zzz'), isEmpty);
  });

  test('managerChipLabel: kata pertama Title Case + elipsis', () {
    expect(managerChipLabel('Rachmad Rizky Nur Fabiyanto'), 'Rachmad…');
    expect(managerChipLabel('gunarto'), 'Gunarto…');
    expect(managerChipLabel(''), '…');
  });
}
