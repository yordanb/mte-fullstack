import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;
import 'package:mte_data_center/src/core/utils/date_fmt.dart';

import '../data/performance_api.dart';
import '../domain/perf_models.dart';

/// Filter Performance meniru Performance.tsx: default 90 hari,
/// mingguan, kecualikan CONTINUE = true.
class PerfFilter {
  final String dateFrom;
  final String dateTo;
  final String granularity; // day | week | month
  final String prefix;
  final String code;
  final bool noCont;

  const PerfFilter({
    required this.dateFrom,
    required this.dateTo,
    this.granularity = 'week',
    this.prefix = '',
    this.code = '',
    this.noCont = true,
  });

  PerfFilter copyWith({
    String? dateFrom,
    String? dateTo,
    String? granularity,
    String? prefix,
    String? code,
    bool? noCont,
  }) =>
      PerfFilter(
        dateFrom: dateFrom ?? this.dateFrom,
        dateTo: dateTo ?? this.dateTo,
        granularity: granularity ?? this.granularity,
        prefix: prefix ?? this.prefix,
        code: code ?? this.code,
        noCont: noCont ?? this.noCont,
      );
}

class PerfFilterNotifier extends Notifier<PerfFilter> {
  @override
  PerfFilter build() {
    final now = DateTime.now();
    return PerfFilter(
      dateFrom: toApiDate(now.subtract(const Duration(days: 90))),
      dateTo: toApiDate(now),
    );
  }

  void apply({
    String? dateFrom,
    String? dateTo,
    String? granularity,
    String? prefix,
    String? code,
    bool? noCont,
  }) {
    state = state.copyWith(
      dateFrom: dateFrom,
      dateTo: dateTo,
      granularity: granularity,
      prefix: prefix?.toUpperCase(),
      code: code,
      noCont: noCont,
    );
  }
}

final perfFilterProvider =
    NotifierProvider<PerfFilterNotifier, PerfFilter>(PerfFilterNotifier.new);

final perfStatsProvider = FutureProvider<PerfStats>((ref) async {
  final f = ref.watch(perfFilterProvider);
  final api = ref.watch(performanceApiProvider);
  try {
    return await api.stats(
      dateFrom: f.dateFrom.isEmpty ? null : f.dateFrom,
      dateTo: f.dateTo.isEmpty ? null : f.dateTo,
      granularity: f.granularity,
      prefix: f.prefix.isEmpty ? null : f.prefix,
      code: f.code.isEmpty ? null : f.code,
      excludeContinue: f.noCont,
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
