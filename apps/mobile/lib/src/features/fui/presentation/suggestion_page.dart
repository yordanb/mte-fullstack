import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';

import 'fui_providers.dart';
import 'oil_table.dart';

/// Suggestion FUI: unit aktif yang sample terakhirnya non-NORMAL + 3 oil
/// terakhirnya. Tombol Suggest pada baris non-NORMAL bila bukan viewer.
/// Meniru SugFuiPage.
class SuggestionPage extends ConsumerWidget {
  const SuggestionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cat = ref.watch(sugCatProvider);
    final groupsAsync = ref.watch(suggestionGroupsProvider);
    final canSuggest = ref.watch(authProvider).role != 'viewer';

    return AppScaffold(
      title: 'Suggestion FUI',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: cat,
                  items: [
                    for (final c in sugCats) DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) {
                    if (v != null) ref.read(sugCatProvider.notifier).set(v);
                  },
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => ref.invalidate(suggestionGroupsProvider),
                  child: const Text('Tampilkan'),
                ),
              ],
            ),
          ),
          Expanded(
            child: groupsAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return Center(
                      child: Text('Tidak ada unit $cat yang perlu follow-up.'));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(suggestionGroupsProvider);
                    await ref.read(suggestionGroupsProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: [
                      Text('${groups.length} unit perlu follow-up'),
                      const SizedBox(height: 8),
                      for (final g in groups) ...[
                        Text(
                          '${g.key}'
                          '${g.rows.first.unitType != null || g.rows.first.unitProduct != null ? ' — ${[g.rows.first.unitType, g.rows.first.unitProduct].where((e) => (e ?? '').isNotEmpty).join(' / ')}' : ''}'
                          ' — ${g.rows.first.condition ?? ''}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Card(
                          child: OilTable(
                            rows: g.rows,
                            onSuggest: canSuggest
                                ? (r) => context.push(
                                      '/suggestion/new?lab_no=${r.labNo}&vesselid=${r.vesselId}&unit_id=${Uri.encodeComponent(r.unitId)}&condition=${r.condition ?? ''}',
                                    )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(suggestionGroupsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
