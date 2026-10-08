import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;
import 'package:mte_data_center/src/core/utils/date_fmt.dart';

import '../data/users_api.dart';
import '../domain/user_models.dart';

const int auditPageSize = 20;

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

final usersListProvider = FutureProvider<List<AppUser>>((ref) async {
  return _guard(ref, () => ref.watch(usersApiProvider).list());
});

final permsProvider = FutureProvider<List<PermRow>>((ref) async {
  return _guard(ref, () => ref.watch(usersApiProvider).perms());
});

/// Filter Audit Log: default 7 hari terakhir (Audit.tsx:5-6).
class AuditFilter {
  final String dateFrom;
  final String dateTo;
  final String username;
  final String path;
  final int page;
  const AuditFilter({
    required this.dateFrom,
    required this.dateTo,
    this.username = '',
    this.path = '',
    this.page = 1,
  });

  AuditFilter copyWith({
    String? dateFrom,
    String? dateTo,
    String? username,
    String? path,
    int? page,
  }) =>
      AuditFilter(
        dateFrom: dateFrom ?? this.dateFrom,
        dateTo: dateTo ?? this.dateTo,
        username: username ?? this.username,
        path: path ?? this.path,
        page: page ?? this.page,
      );
}

class AuditFilterNotifier extends Notifier<AuditFilter> {
  @override
  AuditFilter build() {
    final now = DateTime.now();
    return AuditFilter(
      dateFrom: toApiDate(now.subtract(const Duration(days: 7))),
      dateTo: toApiDate(now),
    );
  }

  void apply({String? dateFrom, String? dateTo, String? username, String? path}) {
    state = state.copyWith(
      dateFrom: dateFrom,
      dateTo: dateTo,
      username: username,
      path: path,
      page: 1,
    );
  }

  void setPage(int p) => state = state.copyWith(page: p);
}

final auditFilterProvider =
    NotifierProvider<AuditFilterNotifier, AuditFilter>(AuditFilterNotifier.new);

final auditProvider = FutureProvider<AuditPageResult>((ref) async {
  final f = ref.watch(auditFilterProvider);
  final api = ref.watch(usersApiProvider);
  return _guard(
    ref,
    () => api.audit(
      dateFrom: f.dateFrom.isEmpty ? null : f.dateFrom,
      dateTo: f.dateTo.isEmpty ? null : f.dateTo,
      username: f.username.isEmpty ? null : f.username,
      path: f.path.isEmpty ? null : f.path,
      page: f.page,
      pageSize: auditPageSize,
    ),
  );
});
