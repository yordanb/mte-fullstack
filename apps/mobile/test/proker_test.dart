import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/features/proker/domain/proker_models.dart';
import 'package:mte_data_center/src/features/proker/presentation/proker_widgets.dart'
    show
        DueLevel,
        PosLevel,
        computeEventDeltas,
        computeExecDeltas,
        dueLevel,
        fmtDateDash,
        fmtHm,
        fmtNum,
        fmtSigned,
        groupReplacements,
        injectorAgeLevel,
        posLevel,
        thermoDeviasiLevel;
import 'package:mte_data_center/src/features/users/domain/user_models.dart'
    show permMenus;

void main() {
  group('parsing Proker pompa primer', () {
    test('ListPage + ProkerUnit.fromJson membaca kolom daftar', () {
      final page = ListPage.fromJson({
        'total': 123,
        'page': 2,
        'page_size': 50,
        'data': [
          {
            'cn': 'EX001',
            'no': 1,
            'unit_model': '966F',
            'product': 'Wheel Loader',
            'unit_type': 'Pompa',
            'engine_merk': 'CAT',
            'engine_model': '3306',
            'hm_now': 12345.5,
            'exec_count': 3,
            'done_count': 2,
            'last_date': '2026-03-01',
            'last_hm': 12000,
          },
        ],
      }, ProkerUnit.fromJson);
      expect(page.total, 123);
      expect(page.page, 2);
      final u = page.data.single;
      expect(u.cn, 'EX001');
      expect(u.engineModel, '3306');
      expect(u.hmNow, 12345.5);
      expect(u.execCount, 3);
      expect(u.doneCount, 2);
      expect(u.lastHm, 12000);
      expect(u.productTypeLabel, 'Wheel Loader · Pompa');
    });

    test('ListPage.fromJson toleran payload kosong', () {
      final page = ListPage.fromJson(const {}, ProkerUnit.fromJson);
      expect(page.total, 0);
      expect(page.page, 1);
      expect(page.data, isEmpty);
    });

    test('ProkerStats + ProkerFilters.fromJson', () {
      final s = ProkerStats.fromJson({
        'units': 40,
        'total': 55,
        'done': 30,
        'plan': 10,
        'late': 5,
        'missed': 10,
        'unit_done': 22,
        'last_date': '2026-10-01',
        'this_year': 8,
        'year': 2026,
        'per_year': [
          {'year': 2026, 'total': 8, 'done': 5},
        ],
      });
      expect(s.units, 40);
      expect(s.unitDone, 22);
      expect(s.thisYear, 8);
      expect(s.year, 2026);
      expect(s.perYear.single.done, 5);

      final f = ProkerFilters.fromJson({
        'product': ['Wheel Loader'],
        'model': ['966F'],
        'type': ['Pompa'],
        'engine': ['3306'],
        'years': [2026, 2025],
        'min_date': '2020-01-01',
        'max_date': '2026-10-01',
        'min_year': 2020,
        'max_year': 2026,
      });
      expect(f.product, ['Wheel Loader']);
      expect(f.engine, ['3306']);
      expect(f.years, [2026, 2025]);
      expect(f.maxYear, 2026);
    });

    test('ProkerDetail.fromJson + computeExecDeltas kronologis', () {
      final d = ProkerDetail.fromJson({
        'unit': {'cn': 'EX001', 'hm_now': 2500},
        'executions': [
          {
            'id': 1,
            'period': '2025 - Pertama',
            'period_year': 2025,
            'period_seq': 1,
            'hm': 1000,
            'service_date': '2025-02-01',
            'status': 'DONE',
          },
          {
            'id': 2,
            'period': '2026 - Pertama',
            'period_year': 2026,
            'period_seq': 1,
            'hm': 2200,
            'service_date': '2026-01-15',
            'status': 'DONE',
          },
          {
            'id': 3,
            'period': '2026 - Kedua',
            'period_year': 2026,
            'period_seq': 2,
            'hm': null,
            'service_date': '2026-06-01',
            'status': 'PLAN',
          },
          {
            'id': 4,
            'period': '2026 - Ketiga',
            'period_year': 2026,
            'period_seq': 3,
            'hm': 2500,
            'service_date': '2026-08-01',
            'status': 'LATE',
          },
        ],
        'stats': {
          'total': 4,
          'done': 2,
          'plan': 1,
          'missed': 1,
          'last_date': '2026-08-01',
          'last_hm': 2500,
          'interval': 2000,
          'due_hm': 4500,
          'sisa_hm': 2000,
        },
      });
      expect(d.unit.cn, 'EX001');
      expect(d.stats.interval, 2000);
      expect(d.stats.sisaHm, 2000);

      final deltas = computeExecDeltas(d.executions);
      expect(deltas[1], isNull); // eksekusi pertama
      expect(deltas[2], 1200);
      expect(deltas[3], isNull); // HM kosong -> lewati (prev tetap 2200)
      expect(deltas[4], 300);
    });
  });

  group('parsing booster', () {
    test('BoosterKpi + BoosterUnit.fromJson (default interval 20000)', () {
      final k = BoosterKpi.fromJson({
        'units': 12,
        'total': 20,
        'ovh': 8,
        'midlife': 12,
        'unit_event': 10,
        'due': 3,
        'last_date': '2026-09-01',
        'interval': 20000,
      });
      expect(k.due, 3);
      expect(k.interval, 20000);

      final u = BoosterUnit.fromJson({
        'cn': 'B001',
        'hm_now': 30000,
        'event_count': 2,
        'last_kind': 'midlife',
        'hours_to_go': -500.0,
      });
      expect(u.intervalHm, 20000);
      expect(u.lastKind, 'MIDLIFE');
      expect(u.hoursToGo, -500.0);
    });

    test('BoosterDetail.fromJson + computeEventDeltas urut HM', () {
      final d = BoosterDetail.fromJson({
        'unit': {'cn': 'B001', 'remarks': 'perlu cek'},
        'events': [
          {'id': 2, 'kind': 'MIDLIFE', 'hm': 5000, 'service_date': '2025-05-01'},
          {'id': 1, 'kind': 'OVH', 'hm': 3000, 'service_date': '2025-01-01'},
          {'id': 3, 'kind': 'OVH', 'hm': 9000, 'service_date': '2026-01-01'},
        ],
        'stats': {
          'events': 3,
          'ovh': 2,
          'midlife': 1,
          'interval_hm': 20000,
          'next_plan_hm': 29000,
          'hours_to_go': -1000,
          'due': true,
        },
      });
      expect(d.unit.remarks, 'perlu cek');
      expect(d.events.first.kind, 'MIDLIFE');
      expect(d.stats.due, isTrue);
      expect(d.stats.nextPlanHm, 29000);

      final deltas = computeEventDeltas(d.events);
      expect(deltas[1], isNull); // 3000 pertama
      expect(deltas[2], 2000); // 5000 - 3000
      expect(deltas[3], 4000); // 9000 - 5000
    });
  });

  group('parsing injector', () {
    test('InjectorDetail.fromJson positions + grup penggantian', () {
      final d = InjectorDetail.fromJson({
        'unit': {'cn': 'I001', 'hm_now': 20000},
        'replacements': [
          {'id': 1, 'seq': 2, 'position': 3, 'hm': 18000, 'status': 'done'},
          {'id': 2, 'seq': 2, 'position': 1, 'hm': 18000, 'status': 'DONE'},
          {'id': 3, 'seq': 1, 'position': 5, 'hm': 5000, 'status': 'PLAN'},
        ],
        'positions': [
          {'position': 1, 'seq': 2, 'hm': 18000, 'status': 'DONE', 'age': 2000.0},
          {'position': 2, 'seq': null, 'hm': null, 'status': null, 'age': null},
        ],
        'stats': {
          'replacements': 3,
          'done': 2,
          'plan': 1,
          'hm_now': 20000,
          'interval_hm': 16000,
          'last_hm': 18000,
          'last_seq': 2,
          'age_hm': 2000,
          'next_plan_hm': 34000,
          'hours_to_go': 14000,
          'due': false,
        },
      });
      expect(d.replacements.first.status, 'DONE');
      expect(d.positions.first.position, 1);
      expect(d.positions[1].hm, isNull);
      expect(d.stats.lastSeq, 2);

      final groups = groupReplacements(d.replacements);
      expect(groups.map((g) => g.seq), [2, 1]);
      expect(groups.first.rows.map((r) => r.position), [1, 3]);
    });

    test('posLevel & injectorAgeLevel mengikuti ambang web', () {
      expect(injectorAgeLevel(null, 16000), DueLevel.none);
      expect(injectorAgeLevel(1000, 16000), DueLevel.ok);
      expect(injectorAgeLevel(12800, 16000), DueLevel.warn); // 80%
      expect(injectorAgeLevel(16000, 16000), DueLevel.bad);

      expect(
          posLevel(
              const InjectorPosition(position: 1, status: 'PLAN'), 16000),
          PosLevel.plan);
      expect(posLevel(const InjectorPosition(position: 2), 16000),
          PosLevel.empty);
      expect(
          posLevel(
              const InjectorPosition(position: 3, hm: 1, age: 16000), 16000),
          PosLevel.bad);
      expect(
          posLevel(
              const InjectorPosition(position: 4, hm: 1, age: 13000), 16000),
          PosLevel.warn);
      expect(
          posLevel(
              const InjectorPosition(position: 5, hm: 1, age: 100), 16000),
          PosLevel.ok);
    });
  });

  group('parsing thermostat', () {
    test('ThermostatUnit.fromJson + label modif', () {
      final u = ThermostatUnit.fromJson({
        'cn': 'T001',
        'hm_now': 13000,
        'interval_hm': 12000,
        'last_hm': 1000,
        'last_date': '2025-01-01',
        'modif_hm': 900,
        'modif_status': '',
        'deviasi': 0.0,
        'lifetime': 12100,
        'due': true,
        'wr': 'WR-123',
        'rad_upper': 80.5,
        'rad_lower': 74.2,
      });
      expect(u.intervalHm, 12000);
      expect(u.modifStatusLabel, 'NOT YET'); // kosong -> NOT YET
      expect(u.deviasi, 0.0);
      expect(u.due, isTrue);
      expect(u.radUpper, 80.5);

      final k = ThermostatKpi.fromJson({
        'units': 5,
        'done': 2,
        'not_yet': 3,
        'due': 1,
        'interval': 12000,
        'last_date': '2026-01-01',
      });
      expect(k.notYet, 3);
      expect(k.interval, 12000);
    });

    test('thermoDeviasiLevel: deviasi >= 0 merah', () {
      expect(thermoDeviasiLevel(null), DueLevel.none);
      expect(thermoDeviasiLevel(-10), DueLevel.ok);
      expect(thermoDeviasiLevel(0), DueLevel.bad);
      expect(dueLevel(0), DueLevel.bad);
      expect(dueLevel(5), DueLevel.ok);
    });
  });

  test('RefreshHmResult.fromJson', () {
    final r = RefreshHmResult.fromJson({
      'updated': 2,
      'unchanged': 1,
      'not_found': 3,
      'details': [
        {
          'cn': 'EX001',
          'before': 100,
          'hm_now': 120,
          'source': 'yazu_dc',
          'changed': true,
        },
      ],
    });
    expect(r.updated, 2);
    expect(r.notFound, 3);
    expect(r.details.single.cn, 'EX001');
    expect(r.details.single.changed, isTrue);

    final kosong = RefreshHmResult.fromJson(const {});
    expect(kosong.updated, 0);
    expect(kosong.details, isEmpty);
  });

  test('fmtNum/fmtHm/fmtSigned/fmtDateDash gaya web', () {
    expect(fmtNum(1234567), '1.234.567');
    expect(fmtNum(1234.6), '1.235'); // dibulatkan seperti Math.round web
    expect(fmtNum(null), '-');
    expect(fmtHm(1234.5678), '1.234,57');
    expect(fmtHm(2000), '2.000');
    expect(fmtSigned(12.5), '+12,5');
    expect(fmtSigned(-12.5), '-12,5');
    expect(fmtSigned(null), '-');
    expect(fmtDateDash(null), '-');
    expect(fmtDateDash('2026-03-01'), '01/03/2026');
  });

  test('permMenus berisi 4 menu Proker', () {
    expect(
      permMenus,
      containsAll([
        'proker',
        'prokerbooster',
        'prokerinjector',
        'prokerthermo',
      ]),
    );
  });
}
