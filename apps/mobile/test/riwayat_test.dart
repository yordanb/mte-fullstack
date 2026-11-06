import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/features/riwayat/domain/riwayat_models.dart';
import 'package:mte_data_center/src/features/riwayat/presentation/riwayat_page.dart'
    show riwayatDaysSince, riwayatFmtDate;

void main() {
  group('riwayatDaysSince', () {
    test('menghitung selisih hari dari hari ini', () {
      final today = DateTime.now();
      final iso = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      expect(riwayatDaysSince(iso), 0);
    });

    test('nilai kosong/null menghasilkan 0', () {
      expect(riwayatDaysSince(null), 0);
      expect(riwayatDaysSince(''), 0);
      expect(riwayatDaysSince('bukan-tanggal'), 0);
    });

    test('menerima datetime panjang (memotong ke 10 karakter)', () {
      final today = DateTime.now();
      final iso = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}T09:30:00.000Z';
      expect(riwayatDaysSince(iso), 0);
    });

    test('tanggal di masa lalu menghasilkan selisih positif', () {
      final past = DateTime.now().subtract(const Duration(days: 10));
      final iso = '${past.year.toString().padLeft(4, '0')}-'
          '${past.month.toString().padLeft(2, '0')}-'
          '${past.day.toString().padLeft(2, '0')}';
      expect(riwayatDaysSince(iso), 10);
    });
  });

  group('riwayatFmtDate', () {
    test('format dd/MM/yyyy dari yyyy-MM-dd', () {
      expect(riwayatFmtDate('2026-11-01'), '01/11/2026');
    });

    test('null/kosong menghasilkan string kosong', () {
      expect(riwayatFmtDate(null), '');
      expect(riwayatFmtDate(''), '');
    });

    test('format tak dikenal dikembalikan apa adanya', () {
      expect(riwayatFmtDate('2026/11/01'), '2026/11/01');
    });
  });

  group('RiwayatIssue.fromJson', () {
    test('mem-parse payload daftar dan memotong tanggal', () {
      final issue = RiwayatIssue.fromJson({
        'id': 7,
        'title': 'Pompa trip',
        'cn': 'CN-01',
        'category': 'Breakdown Unscheduled',
        'status': 'in_progress',
        'start_date': '2026-11-01T08:00:00',
        'end_date': null,
        'progress_count': 3,
        'open_parts': 2,
        'last_progress': 'Ganti seal',
        'last_progress_date': '2026-11-03 10:00',
        'last_progress_by': 'budi',
      });
      expect(issue.id, 7);
      expect(issue.startDate, '2026-11-01');
      expect(issue.endDate, isNull);
      expect(issue.progressCount, 3);
      expect(issue.openParts, 2);
      expect(issue.lastProgress, 'Ganti seal');
    });

    test('nilai yang hilang memakai default aman', () {
      final issue = RiwayatIssue.fromJson(const {});
      expect(issue.id, 0);
      expect(issue.status, 'open');
      expect(issue.progressCount, 0);
    });
  });

  group('RiwayatIssueFull.fromJson', () {
    test('mem-parse issue + progress + parts', () {
      final full = RiwayatIssueFull.fromJson({
        'id': 1,
        'title': 'X',
        'category': 'Inspection',
        'status': 'open',
        'start_date': '2026-11-01',
        'progress': [
          {
            'id': 10,
            'issue_id': 1,
            'seq': 1,
            'log_date': '2026-11-02',
            'description': 'Cek awal',
            'part_required': true,
          }
        ],
        'parts': [
          {
            'id': 20,
            'issue_id': 1,
            'part_name': 'Seal',
            'qty': 2,
            'status': 'ordered',
          }
        ],
      });
      expect(full.progress.length, 1);
      expect(full.progress.first.partRequired, isTrue);
      expect(full.parts.length, 1);
      expect(full.parts.first.qty, 2);
      expect(full.parts.first.status, 'ordered');
    });

    test('progress/parts yang absen jadi list kosong', () {
      final full = RiwayatIssueFull.fromJson({
        'id': 1,
        'title': 'X',
        'category': 'Inspection',
        'status': 'open',
        'start_date': '2026-11-01',
      });
      expect(full.progress, isEmpty);
      expect(full.parts, isEmpty);
    });
  });

  group('RiwayatPhoto', () {
    test('isImage berdasarkan content_type', () {
      expect(
        const RiwayatPhoto(id: 1, origName: 'a.jpg', contentType: 'image/jpeg')
            .isImage,
        isTrue,
      );
      expect(
        const RiwayatPhoto(
                id: 2, origName: 'b.pdf', contentType: 'application/pdf')
            .isImage,
        isFalse,
      );
      expect(const RiwayatPhoto(id: 3, origName: 'c').isImage, isFalse);
    });
  });

  group('label status', () {
    test('riwayatStatusLabel memetakan value → label', () {
      expect(riwayatStatusLabel('in_progress'), 'In Progress');
      expect(riwayatStatusLabel('closed'), 'Closed');
      expect(riwayatStatusLabel('aneh'), 'aneh');
    });

    test('riwayatPartStatusLabel memetakan value → label', () {
      expect(riwayatPartStatusLabel('ordered'), 'Ordered');
      expect(riwayatPartStatusLabel('cancelled'), 'Cancelled');
    });
  });
}
