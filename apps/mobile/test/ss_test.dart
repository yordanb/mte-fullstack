import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mte_data_center/src/features/ss/data/ss_api.dart';
import 'package:mte_data_center/src/features/ss/domain/ss_models.dart';
import 'package:mte_data_center/src/features/ss/presentation/ss_providers.dart';
import 'package:mte_data_center/src/features/ss/presentation/ss_page.dart'
    show abbrName, fmtNum, fmtRupiah;

class _FakeSsApi extends SsApi {
  _FakeSsApi() : super(Dio());

  int kpiCalls = 0;

  @override
  Future<SsKpi> kpi(SsParams p) async {
    kpiCalls++;
    return SsKpi(
      total: 7,
      outstanding: 2,
      pending: 2,
      reward: 0,
      manfaat: 0,
      manfaatRows: 0,
      pencetus: 3,
      gradeAb: 1,
      gradeA: 1,
      gradeF: 0,
    );
  }
}

void main() {
  test('SsParams punya value equality (kunci family provider stabil)', () {
    const a = SsParams(dateBasis: 'menilai', start: '2026-10-01', end: '2026-10-31');
    const b = SsParams(dateBasis: 'menilai', start: '2026-10-01', end: '2026-10-31');
    const c = SsParams(dateBasis: 'laporan', start: '2026-10-01', end: '2026-10-31');

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
    expect({a: 1}[b], 1); // bisa dipakai sebagai key map
  });

  test('provider tidak refetch saat filter setara dipasang ulang', () async {
    final fake = _FakeSsApi();
    final container = ProviderContainer(
      overrides: [ssApiProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final first = await container.read(ssKpiProvider.future);
    expect(first.total, 7);
    expect(fake.kpiCalls, 1);

    // apply() tanpa perubahan nilai harus menghasilkan state yang setara,
    // sehingga provider tidak dibuat ulang (penyebab loading tanpa henti).
    container.read(ssFilterProvider.notifier).apply();
    await container.read(ssKpiProvider.future);
    expect(fake.kpiCalls, 1);
  });

  test('perubahan filter memicu refetch sekali', () async {
    final fake = _FakeSsApi();
    final container = ProviderContainer(
      overrides: [ssApiProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container.read(ssKpiProvider.future);
    container.read(ssFilterProvider.notifier).apply(start: '2026-01-01');
    await container.read(ssKpiProvider.future);

    expect(fake.kpiCalls, 2);
  });

  test('SsTargetCrewResp mem-parse payload API', () {
    final resp = SsTargetCrewResp.fromJson({
      'multiplier': 3,
      'month_count': 1,
      'total_target': 30,
      'total_aktual': 12,
      'approved': 5,
      'menunggu': 7,
      'status_ss_breakdown': [
        {'management': 'Wasono Kusumo', 'jumlah': 4},
      ],
      'last_update': '2026-10-31T05:00:00',
      'data': [
        {'crew': 'Crew A', 'manpower': 10, 'target': 30, 'aktual': 12},
      ],
    });

    expect(resp.totalTarget, 30);
    expect(resp.approved, 5);
    expect(resp.menunggu, 7);
    expect(resp.data.single.crew, 'Crew A');
    expect(resp.statusSsBreakdown.single.jumlah, 4);
    expect(resp.lastUpdate, isNotNull);
  });

  test('format angka & singkatan nama management', () {
    expect(fmtNum(1234), '1.234');
    expect(fmtNum(null), '-');
    expect(fmtRupiah(1500000), contains('1.500.000'));
    expect(abbrName('Wasono Kusumo'), 'Wasono K');
    expect(abbrName('Adi Widodo Darmawan'), 'Adi WD');
    expect(abbrName('  '), '-');
  });
}
