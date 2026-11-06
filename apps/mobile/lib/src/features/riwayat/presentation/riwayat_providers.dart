import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;

import '../data/riwayat_api.dart';
import '../domain/riwayat_models.dart';

/// Filter daftar issue (web: tab Semua/Open/Closed + kategori).
class RiwayatFilter {
  final String status; // 'all' | 'open' | 'closed'
  final String category;
  const RiwayatFilter({this.status = 'all', this.category = ''});

  RiwayatFilter copyWith({String? status, String? category}) => RiwayatFilter(
        status: status ?? this.status,
        category: category ?? this.category,
      );
}

class RiwayatFilterNotifier extends Notifier<RiwayatFilter> {
  @override
  RiwayatFilter build() => const RiwayatFilter();

  void setStatus(String s) => state = state.copyWith(status: s);
  void setCategory(String c) => state = state.copyWith(category: c);
}

final riwayatFilterProvider =
    NotifierProvider<RiwayatFilterNotifier, RiwayatFilter>(
        RiwayatFilterNotifier.new);

/// Daftar issue mengikuti filter.
final riwayatIssuesProvider = FutureProvider<List<RiwayatIssue>>((ref) async {
  final f = ref.watch(riwayatFilterProvider);
  try {
    return await ref.watch(riwayatApiProvider).issues(
          status: f.status,
          category: f.category,
        );
  } catch (e) {
    throw Exception(apiMessage(e));
  }
});

/// Detail issue (issue + progress + parts).
final riwayatIssueProvider =
    FutureProvider.family<RiwayatIssueFull, int>((ref, id) async {
  try {
    return await ref.watch(riwayatApiProvider).issue(id);
  } catch (e) {
    throw Exception(apiMessage(e));
  }
});

/// Part per progress (dipakai ProgressParts).
final riwayatPartsByProgressProvider =
    FutureProvider.family<List<RiwayatPart>, int>((ref, pid) async {
  try {
    return await ref.watch(riwayatApiProvider).partsByProgress(pid);
  } catch (_) {
    return <RiwayatPart>[];
  }
});

/// Foto evidence progress.
final riwayatProgressPhotosProvider =
    FutureProvider.family<List<RiwayatPhoto>, int>((ref, pid) async {
  try {
    return await ref.watch(riwayatApiProvider).progressPhotos(pid);
  } catch (_) {
    return <RiwayatPhoto>[];
  }
});

/// Foto evidence part.
final riwayatPartPhotosProvider =
    FutureProvider.family<List<RiwayatPhoto>, int>((ref, ptid) async {
  try {
    return await ref.watch(riwayatApiProvider).partPhotos(ptid);
  } catch (_) {
    return <RiwayatPhoto>[];
  }
});
