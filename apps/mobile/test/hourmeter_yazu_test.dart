import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/features/hourmeter/domain/hourmeter_models.dart';
import 'package:mte_data_center/src/features/hourmeter/presentation/hourmeter_page.dart'
    show hmNum;
import 'package:mte_data_center/src/features/yazu/domain/yazu_models.dart';

void main() {
  group('Hourmeter', () {
    test('hmNum pemisah ribuan titik, null jadi ·', () {
      expect(hmNum(0), '0');
      expect(hmNum(1234), '1.234');
      expect(hmNum(1234567), '1.234.567');
      expect(hmNum(null), '·');
    });

    test('HourmeterPivot.fromJson mem-parse vals & unit', () {
      final p = HourmeterPivot.fromJson({
        'period': '2026-10',
        'days_in_month': 31,
        'units': [
          {
            'cn': 'WP792',
            'egi': 'RF85MW',
            'opening': 100,
            'vals': {'1': 110, '2': 120},
            'last_day': 2,
            'final': 120,
            'delta': 20,
          }
        ],
      });
      expect(p.period, '2026-10');
      expect(p.daysInMonth, 31);
      expect(p.units.single.cn, 'WP792');
      expect(p.units.single.vals['2'], 120);
      expect(p.units.single.delta, 20);
    });

    test('HourmeterStats.fromJson membaca periods & logs', () {
      final s = HourmeterStats.fromJson({
        'periods': [
          {
            'period': '2026-10',
            'units': 5,
            'values_cnt': 120,
            'uploaded_at': '2026-11-01T00:00:00',
            'uploaded_by': 'admin'
          }
        ],
        'logs': [
          {'period': '2026-10', 'filename': 'a.xlsx', 'rows_units': 5, 'rows_values': 120}
        ],
      });
      expect(s.periods.single.units, 5);
      expect(s.logs.single.filename, 'a.xlsx');
    });
  });

  group('Yazu', () {
    YazuPivot pivot() => YazuPivot.fromJson({
          'year': 2026,
          'month': 11,
          'days_in_month': 30,
          'units': ['U1', 'U2'],
          'cells': {
            'U1': {'1': 100, '2': 112, '4': 140},
            'U2': {'1': 50, '2': 40},
          },
        });

    test('yazuComputeDeltas menormalisasi jarak hari & urut', () {
      final d = yazuComputeDeltas(pivot());
      expect(d['U1']![2], closeTo(12, 1e-9)); // 112-100 / 1
      expect(d['U1']![4], closeTo(14, 1e-9)); // 140-112 / 2
      expect(d['U2']![2], closeTo(-10, 1e-9)); // mundur
    });

    test('yazuDeltaLevel mengikuti ambang web', () {
      expect(yazuDeltaLevel(null), YazuDeltaLevel.none);
      expect(yazuDeltaLevel(-1), YazuDeltaLevel.mundur);
      expect(yazuDeltaLevel(25), YazuDeltaLevel.merah);
      expect(yazuDeltaLevel(20), YazuDeltaLevel.orange);
      expect(yazuDeltaLevel(12), YazuDeltaLevel.hijau);
      expect(yazuDeltaLevel(5), YazuDeltaLevel.biasa);
    });

    test('yazuAnomalySummary menghitung tiap kategori', () {
      final d = yazuComputeDeltas(pivot());
      final s = yazuAnomalySummary(d);
      // U1: 12 (hijau), 14 (hijau — 14 tidak > 14); U2: -10 (mundur).
      expect(s.hijau, 2);
      expect(s.orange, 0);
      expect(s.mundur, 1);
    });

    test('yazuDeltaTitle', () {
      expect(yazuDeltaTitle(-3.5), 'ANOMALI: HM mundur -3.5 jam/hari');
      expect(yazuDeltaTitle(12.25), 'Δ 12.3 jam/hari');
    });
  });
}
