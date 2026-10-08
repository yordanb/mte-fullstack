import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;
import 'package:mte_data_center/src/core/utils/date_fmt.dart';
import 'package:mte_data_center/src/features/dbr/data/dbr_api.dart';
import 'package:mte_data_center/src/features/dbr/domain/dbr_models.dart';

import '../data/fui_api.dart';
import '../domain/fui_models.dart';

const List<String> sugCats = ['BIGWHEEL', 'LIGHTING', 'MOBILE', 'PUMPING'];
const int reportPageSize = 20;

Future<T> _guard<T>(Ref ref, Future<T> Function() fn) async {
  try {
    return await fn();
  } on DioException catch (e) {
    if (e.response?.statusCode == 401) {
      await ref.read(authProvider.notifier).forceLogout();
    }
    throw apiMessage(e);
  } catch (e) {
    throw apiMessage(e);
  }
}

/// CN dossier yang sedang dibuka (uppercase).
class DossierCnNotifier extends Notifier<String> {
  @override
  String build() => '';
  void open(String cn) => state = cn.trim().toUpperCase();
}

final dossierCnProvider = NotifierProvider<DossierCnNotifier, String>(DossierCnNotifier.new);

/// 10 DBR USM terbaru tanpa CONTINUE (server-side, FuiPage:902).
final dossierDbrProvider = FutureProvider<List<DbrRow>>((ref) async {
  final cn = ref.watch(dossierCnProvider);
  if (cn.isEmpty) return const [];
  final api = ref.watch(dbrApiProvider);
  final res = await _guard(
    ref,
    () => api.records(
      dateFrom: '2020-01-01',
      dateTo: toApiDate(DateTime.now()),
      cn: cn,
      code: 'USM',
      excludeContinue: true,
      page: 1,
      pageSize: 10,
    ),
  );
  return res.rows;
});

class DossierUnit {
  final String unit;
  final List<OilRow> rows;
  const DossierUnit(this.unit, this.rows);
}

/// 10 oil terakhir per component (units lalu fan-out, FuiPage:908-911).
final dossierOilsProvider = FutureProvider<List<DossierUnit>>((ref) async {
  final cn = ref.watch(dossierCnProvider);
  if (cn.isEmpty) return const [];
  final api = ref.watch(fuiApiProvider);
  final units = await _guard(ref, () => api.vesselUnits(cn));
  final out = await Future.wait(
    units.map((u) async => DossierUnit(
        u, await _guard(ref, () => api.oilByUnit(cn, u, limit: 10)))),
  );
  return out.where((e) => e.rows.isNotEmpty).toList();
});

/// Kategori suggestion aktif (default MOBILE seperti web).
class SugCatNotifier extends Notifier<String> {
  @override
  String build() => 'MOBILE';
  void set(String v) => state = v;
}

final sugCatProvider = NotifierProvider<SugCatNotifier, String>(SugCatNotifier.new);

final suggestionGroupsProvider = FutureProvider<List<SuggestGroup>>((ref) async {
  final cat = ref.watch(sugCatProvider);
  final api = ref.watch(fuiApiProvider);
  final rows = await _guard(ref, () => api.suggestions(cat));
  return groupSuggestions(rows);
});

/// Filter Report Follow Up (SugReportPage).
class ReportFilter {
  final String cat;
  final String q;
  final String st; // '' = semua, '1' = sudah, '0' = belum
  final int page;
  const ReportFilter({this.cat = '', this.q = '', this.st = '', this.page = 1});

  ReportFilter copyWith({String? cat, String? q, String? st, int? page}) => ReportFilter(
        cat: cat ?? this.cat,
        q: q ?? this.q,
        st: st ?? this.st,
        page: page ?? this.page,
      );
}

class ReportFilterNotifier extends Notifier<ReportFilter> {
  @override
  ReportFilter build() => const ReportFilter();

  void apply({String? cat, String? q, String? st}) {
    state = state.copyWith(cat: cat, q: q, st: st, page: 1);
  }

  void setPage(int p) => state = state.copyWith(page: p);
}

final reportFilterProvider =
    NotifierProvider<ReportFilterNotifier, ReportFilter>(ReportFilterNotifier.new);

final suggestReportProvider = FutureProvider<SuggestReportPageResult>((ref) async {
  final f = ref.watch(reportFilterProvider);
  final api = ref.watch(fuiApiProvider);
  return _guard(
    ref,
    () => api.suggestReport(
      category: f.cat.isEmpty ? null : f.cat,
      search: f.q.isEmpty ? null : f.q,
      hasSuggest: f.st == '' ? null : f.st == '1',
      page: f.page,
      pageSize: reportPageSize,
    ),
  );
});

final suggestHistoryProvider =
    FutureProvider.family<List<Suggest>, String>((ref, labNo) async {
  final api = ref.watch(fuiApiProvider);
  return _guard(ref, () => api.history(labNo));
});

void invalidateFuiLists(WidgetRef ref) {
  ref.invalidate(suggestionGroupsProvider);
  ref.invalidate(suggestReportProvider);
}
