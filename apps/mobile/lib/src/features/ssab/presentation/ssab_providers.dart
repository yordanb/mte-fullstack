import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/network/dio_client.dart' show apiMessage;
import '../data/ssab_api.dart';
import '../domain/ssab_models.dart';

/// Tahun terpilih halaman SS AB — default tahun berjalan (web SsAbPage).
class SsabYearNotifier extends Notifier<int> {
  @override
  int build() => DateTime.now().year;

  void set(int year) => state = year;
}

final ssabYearProvider =
    NotifierProvider<SsabYearNotifier, int>(SsabYearNotifier.new);

/// Bungkus pemanggilan API: 401 -> paksa logout, error lain -> pesan rapi.
Future<T> _guard<T>(Ref ref, Future<T> Function() run) async {
  try {
    return await run();
  } on DioException catch (e) {
    if (e.response?.statusCode == 401) {
      await ref.read(authProvider.notifier).forceLogout();
    }
    throw apiMessage(e);
  } catch (e) {
    throw apiMessage(e);
  }
}

/// Data SS AB lengkap untuk tahun terpilih (KPI, kalender, dept, records,
/// waiting approval). Refetch otomatis saat tahun berubah.
final ssabDataProvider = FutureProvider<SsAbResp>((ref) async {
  final year = ref.watch(ssabYearProvider);
  final api = ref.watch(ssabApiProvider);
  return _guard(ref, () => api.fetch(year: year));
});
