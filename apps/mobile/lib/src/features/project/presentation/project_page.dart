import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../domain/project_models.dart';
import 'project_detail_sheet.dart';
import 'project_forms.dart';
import 'project_providers.dart';
import 'project_widgets.dart';

/// Daftar Project Management — paritas web Project.tsx (filter + tabel + paging).
class ProjectPageList extends ConsumerStatefulWidget {
  const ProjectPageList({super.key});

  @override
  ConsumerState<ProjectPageList> createState() => _ProjectPageListState();
}

class _ProjectPageListState extends ConsumerState<ProjectPageList> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(projectListProvider);
    final auth = ref.watch(authProvider);
    final page = ref.watch(projectPageProvider);

    return AppScaffold(
      title: 'Project Management',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(projectListProvider);
          await ref.read(projectListProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text('Rencana timeframe + update tahapan + eviden',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            _filters(auth),
            const SizedBox(height: 10),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(projectListProvider),
              ),
              data: (p) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Total ${p.total}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  if (p.data.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                          child: Text('Belum ada project.',
                              style: TextStyle(color: Colors.grey))),
                    )
                  else
                    for (final r in p.data) _projectCard(r),
                  const SizedBox(height: 10),
                  _pager(p, page),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      floatingActionButton: auth.can('project', 'add')
          ? FloatingActionButton(
              onPressed: () => showProjectForm(context, ref),
              tooltip: 'Project baru',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _filters(AuthState auth) {
    final filter = ref.watch(projectFilterProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 180,
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
                hintText: 'Cari project / PIC / CN', isDense: true),
            onSubmitted: (v) {
              ref.read(projectFilterProvider.notifier).setSearch(v.trim());
              ref.read(projectPageProvider.notifier).set(1);
            },
          ),
        ),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String>(
            value: filter.status,
            isDense: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: '', child: Text('Status: semua')),
              for (final e in projStLabel.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) {
              ref.read(projectFilterProvider.notifier).setStatus(v ?? '');
              ref.read(projectPageProvider.notifier).set(1);
            },
          ),
        ),
        FilledButton(
          onPressed: () {
            ref.read(projectFilterProvider.notifier).setSearch(
                _search.text.trim());
            ref.read(projectPageProvider.notifier).set(1);
          },
          child: const Text('Tampilkan'),
        ),
      ],
    );
  }

  Widget _projectCard(Project r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => showProjectDetail(context, ref, r.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(r.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  ProjBadge(status: r.derived),
                ],
              ),
              if ((r.pic ?? '').isNotEmpty)
                Text('PIC: ${r.pic}',
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              Text(
                [
                  r.cn,
                  r.crew,
                  'Target ${projFmtD(r.targetDate)}',
                  '${r.nstage} tahap',
                ].where((e) => e != null && e.isNotEmpty && e != 'Target ')
                    .join(' • '),
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _bar(r.progress)),
                  const SizedBox(width: 8),
                  Text('${r.progress}%',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(int pct) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: (pct.clamp(0, 100)) / 100,
          minHeight: 7,
          backgroundColor: Colors.grey.shade200,
        ),
      );

  Widget _pager(ProjectPage p, int page) {
    final pages = (p.total / p.pageSize).ceil().clamp(1, 999999);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: page <= 1
              ? null
              : () => ref.read(projectPageProvider.notifier).set(page - 1),
          child: const Text('‹ Prev'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Halaman $page dari $pages',
              style: const TextStyle(fontSize: 12)),
        ),
        OutlinedButton(
          onPressed: page >= pages
              ? null
              : () => ref.read(projectPageProvider.notifier).set(page + 1),
          child: const Text('Next ›'),
        ),
      ],
    );
  }
}
