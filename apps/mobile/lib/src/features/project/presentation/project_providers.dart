import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;

import '../data/project_api.dart';
import '../domain/project_models.dart';

/// Filter daftar project (web q + st).
class ProjectFilter {
  final String search;
  final String status;
  const ProjectFilter({this.search = '', this.status = ''});

  ProjectFilter copyWith({String? search, String? status}) => ProjectFilter(
        search: search ?? this.search,
        status: status ?? this.status,
      );
}

class ProjectFilterNotifier extends Notifier<ProjectFilter> {
  @override
  ProjectFilter build() => const ProjectFilter();

  void setSearch(String s) => state = state.copyWith(search: s);
  void setStatus(String s) => state = state.copyWith(status: s);
}

final projectFilterProvider =
    NotifierProvider<ProjectFilterNotifier, ProjectFilter>(
        ProjectFilterNotifier.new);

/// Halaman saat ini (web page state).
final projectPageProvider = NotifierProvider<ProjectPageNumNotifier, int>(
    ProjectPageNumNotifier.new);

class ProjectPageNumNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void set(int p) => state = p < 1 ? 1 : p;
}

/// Daftar project mengikuti filter + halaman.
final projectListProvider = FutureProvider<ProjectPage>((ref) async {
  final f = ref.watch(projectFilterProvider);
  final page = ref.watch(projectPageProvider);
  try {
    return await ref.watch(projectApiProvider).list(
          search: f.search,
          status: f.status,
          page: page,
        );
  } catch (e) {
    throw Exception(apiMessage(e));
  }
});

/// Detail project (project + stages + updates).
final projectDetailProvider =
    FutureProvider.family<Project, String>((ref, id) async {
  try {
    return await ref.watch(projectApiProvider).detail(id);
  } catch (e) {
    throw Exception(apiMessage(e));
  }
});
