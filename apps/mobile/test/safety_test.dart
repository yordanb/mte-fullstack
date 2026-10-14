import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/features/safety/domain/safety_models.dart';

void main() {
  test('shortName: >2 kata jadi 2 kata + inisial', () {
    expect(shortName('RAHMAT FITRIADI M'), 'RAHMAT FITRIADI M');
    expect(shortName('RAHMAT FITRIADI MAULANA'), 'RAHMAT FITRIADI M');
    expect(shortName('BUDI'), 'BUDI');
    expect(shortName(null), '');
  });

  test('monthEnd menangani akhir bulan + kabisat', () {
    expect(monthStart(2026, 10), '2026-10-01');
    expect(monthEnd(2026, 10), '2026-10-31');
    expect(monthEnd(2026, 2), '2026-02-28');
    expect(monthEnd(2024, 2), '2024-02-29');
  });

  test('badge P1..P5 mengikuti aturan web', () {
    const r = SafetyRow(
      id: 1,
      submittedAt: '2026-10-01T08:00:00',
      p1Doa: 'SUDAH',
      p2Apd: 'SIAP',
      p2Stretch: 'SIAP',
      p3Housekeeping: 'SESUAI PRINSIP',
      p4Alat: 'SUDAH SESUAI',
      p5Prosedur: 'SUDAH SESUAI PROSEDUR',
    );
    expect([r.p1Ok, r.p2Ok, r.p3Ok, r.p4Ok, r.p5Ok],
        everyElement(isTrue));
    const bad = SafetyRow(id: 2, submittedAt: '', p2Apd: 'SIAP');
    expect(bad.p2Ok, isFalse); // stretch hilang
    expect(bad.p1Ok, isFalse);
  });

  test('temuan menggabung 4 kolom desc', () {
    const r = SafetyRow(
        id: 1, submittedAt: '', p3Desc: 'A', followup: 'B');
    expect(r.temuan, 'A | B');
    expect(const SafetyRow(id: 2, submittedAt: '').temuan, '');
  });

  test('teks WA bomak + r1bi persis format web', () {
    final bomak = buildBomakWaText(
      section: '',
      rows: const [
        {'nama': 'Budi', 'submittedAt': '2026-10-05T08:00:00'},
      ],
      syncDate: '06/10/2026',
    );
    expect(
        bomak,
        'Data Bomak semua :\n'
        '1. Budi - 05/10/26\n'
        'Last data update: 06/10/2026');

    final ribi = buildRibiWaText(
      section: 'Pumping',
      rows: const [
        {'nama': 'Ani', 'tanggal': '2026-10-04'},
      ],
      syncDate: '',
    );
    expect(
        ribi,
        'Data R1BI Pumping :\n'
        '1. Ani - 04/10/26\n'
        'Last data update: ');
  });

  test('R1BI HIGH RISK terdeteksi', () {
    const r = RibiRow(tanggal: '2026-10-04', aktivitas: 'HIGH RISK');
    expect(r.isHighRisk, isTrue);
    expect(
        const RibiRow(tanggal: '2026-10-04', aktivitas: 'LOW RISK')
            .isHighRisk,
        isFalse);
  });
}
