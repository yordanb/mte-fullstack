import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/utils/date_fmt.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';

import 'fui_providers.dart';
import 'oil_table.dart';

/// Report Follow Up: oil terakhir non-NORMAL per unit + status suggest.
/// Riwayat + tombol Suggest per baris. Meniru SugReportPage.
class ReportFollowUpPage extends ConsumerStatefulWidget {
  const ReportFollowUpPage({super.key});

  @override
  ConsumerState<ReportFollowUpPage> createState() => _ReportFollowUpPageState();
}

class _ReportFollowUpPageState extends ConsumerState<ReportFollowUpPage> {
  late final TextEditingController _q;

  @override
  void initState() {
    super.initState();
    _q = TextEditingController(text: ref.read(reportFilterProvider).q);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(reportFilterProvider);
    final repAsync = ref.watch(suggestReportProvider);
    final canSuggest = ref.watch(authProvider).role != 'viewer';

    return AppScaffold(
      title: 'Report Follow Up',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: f.cat,
                  hint: const Text('Kategori: semua'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Kategori: semua')),
                    for (final c in sugCats)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => ref
                      .read(reportFilterProvider.notifier)
                      .apply(cat: v ?? ''),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _q,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Cari CN / unit',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: f.st,
                  hint: const Text('Suggest: semua'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Suggest: semua')),
                    DropdownMenuItem(value: '1', child: Text('Sudah ada')),
                    DropdownMenuItem(value: '0', child: Text('Belum ada')),
                  ],
                  onChanged: (v) => ref
                      .read(reportFilterProvider.notifier)
                      .apply(st: v ?? ''),
                ),
                FilledButton(
                  onPressed: () => ref
                      .read(reportFilterProvider.notifier)
                      .apply(q: _q.text.trim().toUpperCase()),
                  child: const Text('Tampilkan'),
                ),
              ],
            ),
          ),
          Expanded(
            child: repAsync.when(
              data: (res) {
                final pages =
                    (res.total / reportPageSize).ceil().clamp(1, 1 << 30);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Total ${res.total}'),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(suggestReportProvider);
                          await ref.read(suggestReportProvider.future);
                        },
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Vessel')),
                                DataColumn(label: Text('Unit')),
                                DataColumn(label: Text('Type / Product')),
                                DataColumn(label: Text('Sample')),
                                DataColumn(label: Text('HM')),
                                DataColumn(label: Text('Condition')),
                                DataColumn(label: Text('Suggest')),
                                DataColumn(label: Text('Saran Terakhir')),
                                DataColumn(label: Text('Aksi')),
                              ],
                              rows: [
                                for (final r in res.rows)
                                  DataRow(cells: [
                                    DataCell(Text(r.vesselId)),
                                    DataCell(Text(r.unitId)),
                                    DataCell(Text(r.typeProduct.isEmpty
                                        ? '-'
                                        : r.typeProduct)),
                                    DataCell(Text(fmtDate(r.sampleDate))),
                                    DataCell(Text(r.unitTime ?? '-')),
                                    DataCell(Text(r.condition,
                                        style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold))),
                                    DataCell(SuggestBadge(
                                        count: r.suggestCount)),
                                    DataCell(ConstrainedBox(
                                      constraints: const BoxConstraints(
                                          maxWidth: 220),
                                      child: Text(
                                        r.latestSuggestion != null
                                            ? '${r.latestSuggestion} — ${r.latestPic ?? ''} (${r.latestBy ?? ''})'
                                            : '-',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )),
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(
                                          onPressed: () => context.push(
                                              '/report-followup/history?lab_no=${r.labNo}'),
                                          child: const Text('Riwayat'),
                                        ),
                                        if (canSuggest)
                                          TextButton(
                                            onPressed: () => context.push(
                                                '/suggestion/new?lab_no=${r.labNo}&vesselid=${r.vesselId}&unit_id=${Uri.encodeComponent(r.unitId)}&condition=${r.condition}'),
                                            child: const Text('Suggest'),
                                          ),
                                      ],
                                    )),
                                  ]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (res.rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('Tidak ada data.')),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: res.page <= 1
                                ? null
                                : () => ref
                                    .read(reportFilterProvider.notifier)
                                    .setPage(res.page - 1),
                            child: const Text('‹ Prev'),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Halaman ${res.page} dari $pages'),
                          ),
                          OutlinedButton(
                            onPressed: res.page >= pages
                                ? null
                                : () => ref
                                    .read(reportFilterProvider.notifier)
                                    .setPage(res.page + 1),
                            child: const Text('Next ›'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(suggestReportProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
