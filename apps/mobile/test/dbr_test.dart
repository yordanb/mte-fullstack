import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mte_data_center/src/features/dbr/data/dbr_api.dart';
import 'package:mte_data_center/src/features/dbr/domain/dbr_models.dart';
import 'package:mte_data_center/src/features/dbr/presentation/dbr_providers.dart';

/// Fake API: rekam query terakhir tanpa jaringan.
class _FakeDbrApi extends DbrApi {
  _FakeDbrApi() : super(Dio());
  String? lastCode;
  String? lastPrefix;

  @override
  Future<DbrPageResult> records({
    String? dateFrom,
    String? dateTo,
    String? cn,
    String? code,
    String? prefix,
    bool excludeContinue = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    lastCode = code;
    lastPrefix = prefix;
    return const DbrPageResult(total: 0, page: 1);
  }

  @override
  Future<List<String>> codes() async => const [];
}

void main() {
  test('DbrRow: CONTINUE terdeteksi case-insensitive', () {
    final c = DbrRow.fromJson({
      'id': 1,
      'date': '2026-09-01T00:00:00',
      'cn': 'TL960',
      'action': 'Continue',
    });
    expect(c.isContinue, isTrue);
    expect(c.date, '2026-09-01');

    final n = DbrRow.fromJson({'id': 2, 'date': '2026-09-01', 'cn': 'TL960'});
    expect(n.isContinue, isFalse);
    expect(n.code, isNull);
  });

  test('filter client-side seperti web: hanya non-CONTINUE', () {
    final rows = [
      const DbrRow(id: 1, date: '2026-09-01', cn: 'A', action: 'CONTINUE'),
      const DbrRow(id: 2, date: '2026-09-01', cn: 'B', action: 'GANTI OLI'),
      const DbrRow(id: 3, date: '2026-09-01', cn: 'C'),
    ];
    final shown = rows.where((r) => !r.isContinue).toList();
    expect(shown.map((e) => e.id), [2, 3]);
  });

  test('toggle Pumping: code dikosongkan + page reset (web ce41a49)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(dbrFilterProvider.notifier);

    n.apply(cn: 'wp', code: 'GANTI OLI');
    n.setPage(3);
    var f = container.read(dbrFilterProvider);
    expect(f.cn, 'WP'); // CN uppercase seperti web
    expect(f.code, 'GANTI OLI');

    n.setPumping(true);
    f = container.read(dbrFilterProvider);
    expect(f.pumping, isTrue);
    expect(f.code, '');
    expect(f.page, 1);
    expect(f.cn, 'WP'); // CN tidak direset

    n.setPumping(false);
    f = container.read(dbrFilterProvider);
    expect(f.pumping, isFalse);
    expect(f.code, '');
  });

  test('query pumping: prefix=WP & code diabaikan (web ce41a49)', () async {
    final fake = _FakeDbrApi();
    final container = ProviderContainer(overrides: [dbrApiProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final n = container.read(dbrFilterProvider.notifier);
    n.apply(code: 'GANTI OLI');
    await container.read(dbrRecordsProvider.future);
    expect(fake.lastPrefix, isNull);
    expect(fake.lastCode, 'GANTI OLI');

    n.setPumping(true);
    await container.read(dbrRecordsProvider.future);
    expect(fake.lastPrefix, 'WP');
    expect(fake.lastCode, isNull);
  });
}
