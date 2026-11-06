import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/features/project/domain/project_models.dart';
import 'package:mte_data_center/src/features/project/presentation/project_widgets.dart'
    show projFmtD;

void main() {
  group('projFmtD', () {
    test('yyyy-MM-dd → dd/MM/yyyy', () {
      expect(projFmtD('2026-11-01'), '01/11/2026');
    });

    test('menerima datetime panjang (potong ke 10)', () {
      expect(projFmtD('2026-11-01T08:00:00'), '01/11/2026');
    });

    test('null/kosong → string kosong', () {
      expect(projFmtD(null), '');
      expect(projFmtD(''), '');
    });
  });

  group('label status project', () {
    test('projStatusLabel memetakan value → label', () {
      expect(projStatusLabel('ON_TRACK'), 'On Track');
      expect(projStatusLabel('TERLAMBAT'), 'Terlambat');
      expect(projStatusLabel('SELESAI'), 'Selesai');
      expect(projStatusLabel('aneh'), 'aneh');
    });
  });

  group('Project.fromJson', () {
    test('mem-parse daftar + memotong tanggal', () {
      final p = Project.fromJson({
        'id': 'abc',
        'name': 'Overhaul WP855',
        'pic': 'budi',
        'cn': 'WP855',
        'crew': 'Pumping',
        'target_date': '2026-12-31T00:00:00',
        'progress': 40,
        'derived': 'ON_TRACK',
        'nstage': 3,
      });
      expect(p.id, 'abc');
      expect(p.targetDate, '2026-12-31');
      expect(p.progress, 40);
      expect(p.nstage, 3);
      expect(p.stages, isEmpty);
    });

    test('nilai hilang → default aman', () {
      final p = Project.fromJson(const {});
      expect(p.id, '');
      expect(p.progress, 0);
      expect(p.derived, 'BELUM_MULAI');
    });
  });

  group('Project.fromJson (detail)', () {
    test('mem-parse stages + updates + photos', () {
      final p = Project.fromJson({
        'id': '1',
        'name': 'X',
        'progress': 50,
        'derived': 'ON_TRACK',
        'stages': [
          {
            'id': 's1',
            'name': 'Pembongkaran',
            'plan_start': '2026-11-01',
            'plan_end': '2026-11-05',
            'weight': 2,
            'progress': 60,
            'derived': 'AT_RISK',
            'latest': {
              'id': 'u1',
              'date': '2026-11-03',
              'progress': 60,
              'status': 'AT_RISK',
              'note': 'terkendala izin',
            },
            'updates': [
              {
                'id': 'u1',
                'date': '2026-11-03',
                'progress': 60,
                'status': 'AT_RISK',
                'photo_list': [
                  {'id': 'ph1', 'orig_name': 'a.jpg'},
                ],
              }
            ],
          }
        ],
      });
      expect(p.stages.length, 1);
      final s = p.stages.first;
      expect(s.planEnd, '2026-11-05');
      expect(s.weight, 2);
      expect(s.derived, 'AT_RISK');
      expect(s.latest?.note, 'terkendala izin');
      expect(s.updates.first.photoList.first.id, 'ph1');
      expect(s.updates.first.photoList.first.origName, 'a.jpg');
    });

    test('stage tanpa plan tanggal tetap valid', () {
      final p = Project.fromJson({
        'id': '1',
        'name': 'X',
        'stages': [
          {'id': 's1', 'name': 'Y', 'progress': 0, 'derived': 'BELUM_MULAI'},
        ],
      });
      expect(p.stages.first.planStart, isNull);
      expect(p.stages.first.updates, isEmpty);
    });
  });

  group('ProjectPage.fromJson', () {
    test('mem-parse total/page/data', () {
      final pp = ProjectPage.fromJson({
        'total': 1,
        'page': 1,
        'page_size': 20,
        'data': [
          {'id': '1', 'name': 'A', 'progress': 10, 'derived': 'ON_TRACK'}
        ],
      });
      expect(pp.total, 1);
      expect(pp.page, 1);
      expect(pp.data.length, 1);
      expect(pp.data.first.name, 'A');
    });
  });
}
