import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;
import 'package:mte_data_center/src/core/utils/date_fmt.dart';

import '../data/dbr_api.dart';
import '../domain/dbr_models.dart';

const int dbrPageSize = 20;

/// Filter DBR meniru DbrPage web: default 30 hari terakhir (todayLocal(30)),
/// CN uppercase, code (+__EMPTY__ = Code kosong). hideContinue = filter
/// client-side, TIDAK dikirim ke server (Pages.tsx:269). pumping = toggle
/// "Pumping" web ce41a49: prefix=WP, semua code (dropdown Code diabaikan).
class DbrFilter {
  final String dateFrom;
  final String dateTo;
  final String cn;
  final String code;
  final int page;
  final bool hideContinue;
  final bool pumping;

  const DbrFilter({
    required this.dateFrom,
    required this.dateTo,
    this.cn = '',
    this.code = '',
    this.page = 1,
    this.hideContinue = false,
    this.pumping = false,
  });

  DbrFilter copyWith({
    String? dateFrom,
    String? dateTo,
    String? cn,
    String? code,
    int? page,
    bool? hideContinue,
    bool? pumping,
  }) =>
      DbrFilter(
        dateFrom: dateFrom ?? this.dateFrom,
        dateTo: dateTo ?? this.dateTo,
        cn: cn ?? this.cn,
        code: code ?? this.code,
        page: page ?? this.page,
        hideContinue: hideContinue ?? this.hideContinue,
        pumping: pumping ?? this.pumping,
      );
}

class DbrFilterNotifier extends Notifier<DbrFilter> {
  @override
  DbrFilter build() {
    final now = DateTime.now();
    return DbrFilter(
      dateFrom: toApiDate(now.subtract(const Duration(days: 30))),
      dateTo: toApiDate(now),
    );
  }

  void apply({String? dateFrom, String? dateTo, String? cn, String? code}) {
    state = state.copyWith(
      dateFrom: dateFrom,
      dateTo: dateTo,
      cn: cn?.toUpperCase(),
      code: code,
      page: 1,
    );
  }

  void setPage(int p) => state = state.copyWith(page: p);
  void setHideContinue(bool v) => state = state.copyWith(hideContinue: v);

  /// Toggle "Pumping" (web ce41a49): prefix=WP + semua code. Saat aktif
  /// dropdown Code dikosongkan (dan diabaikan di query).
  void setPumping(bool v) => state = state.copyWith(
        pumping: v,
        code: v ? '' : state.code,
        page: 1,
      );
}

final dbrFilterProvider = NotifierProvider<DbrFilterNotifier, DbrFilter>(DbrFilterNotifier.new);

final dbrRecordsProvider = FutureProvider<DbrPageResult>((ref) async {
  final f = ref.watch(dbrFilterProvider);
  final api = ref.watch(dbrApiProvider);
  try {
    return await api.records(
      dateFrom: f.dateFrom.isEmpty ? null : f.dateFrom,
      dateTo: f.dateTo.isEmpty ? null : f.dateTo,
      cn: f.cn.isEmpty ? null : f.cn,
      code: f.pumping || f.code.isEmpty ? null : f.code,
      prefix: f.pumping ? 'WP' : null,
      page: f.page,
      pageSize: dbrPageSize,
    );
  } on DioException catch (e) {
    if (e.response?.statusCode == 401) {
      await ref.read(authProvider.notifier).forceLogout();
    }
    throw apiMessage(e);
  } catch (e) {
    throw apiMessage(e);
  }
});

final dbrCodesProvider = FutureProvider<List<String>>((ref) async {
  try {
    return await ref.watch(dbrApiProvider).codes();
  } catch (_) {
    return <String>[];
  }
});
