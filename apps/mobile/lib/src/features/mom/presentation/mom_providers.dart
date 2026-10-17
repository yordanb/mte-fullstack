import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;

import '../data/mom_api.dart';
import '../domain/mom_models.dart';

/// Filter list meeting: status (all/open/closed) + category.
class MomFilter {
  final String status;
  final String category;
  const MomFilter({this.status = 'all', this.category = ''});
}

class MomFilterNotifier extends Notifier<MomFilter> {
  @override
  MomFilter build() => const MomFilter();
  void setStatus(String s) => state = MomFilter(status: s, category: state.category);
  void setCategory(String c) => state = MomFilter(status: state.status, category: c);
}

final momFilterProvider =
    NotifierProvider<MomFilterNotifier, MomFilter>(MomFilterNotifier.new);

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

final momListProvider = FutureProvider<List<MomMeeting>>((ref) async {
  final f = ref.watch(momFilterProvider);
  final api = ref.watch(momApiProvider);
  return _guard(ref, () => api.listMeetings(
        status: f.status == 'all' ? null : f.status,
        category: f.category.isEmpty ? null : f.category,
      ));
});

final momDetailProvider = FutureProvider.family<MomMeetingDetail, int>((ref, id) async {
  final api = ref.watch(momApiProvider);
  return _guard(ref, () => api.getMeeting(id));
});

void invalidateMom(WidgetRef ref) {
  ref.invalidate(momListProvider);
}
