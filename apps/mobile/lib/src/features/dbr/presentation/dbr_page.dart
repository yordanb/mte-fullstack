import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/utils/date_fmt.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';

import '../domain/dbr_models.dart';
import 'dbr_providers.dart';

/// Kolom tampil DBR_COLS web (Pages.tsx:247-254).
const _cols = [
  ('date', 'DATE'),
  ('cn', 'C/N'),
  ('section', 'SECTION'),
  ('trouble', 'Trouble'),
  ('code', 'Code'),
  ('hm_start', 'HM Start'),
  ('loc', 'LOC'),
  ('start_breakdown', 'Start BD'),
  ('action', 'Action'),
  ('mechanic', 'Mechanic'),
  ('gl', 'GL'),
];

String _cell(DbrRow r, String key) => switch (key) {
      'date' => fmtDdbr(r.date),
      'cn' => r.cn,
      'section' => r.section ?? '',
      'trouble' => r.trouble ?? '',
      'code' => r.code ?? '',
      'hm_start' => r.hmStart ?? '',
      'loc' => r.loc ?? '',
      'start_breakdown' => r.startBreakdown ?? '',
      'action' => r.action ?? '',
      'mechanic' => r.mechanic ?? '',
      'gl' => r.gl ?? '',
      _ => '',
    };

/// DBR Breakdown: filter tanggal/CN/code + sembunyikan CONTINUE
/// (client-side) + paginasi server. Meniru DbrPage web.
class DbrPage extends ConsumerStatefulWidget {
  const DbrPage({super.key});

  @override
  ConsumerState<DbrPage> createState() => _DbrPageState();
}

class _DbrPageState extends ConsumerState<DbrPage> {
  late final TextEditingController _cn;

  @override
  void initState() {
    super.initState();
    _cn = TextEditingController(text: ref.read(dbrFilterProvider).cn);
  }

  @override
  void dispose() {
    _cn.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final f = ref.read(dbrFilterProvider);
    final cur = DateTime.tryParse(isFrom ? f.dateFrom : f.dateTo) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    var df = isFrom ? toApiDate(d) : f.dateFrom;
    var dt = isFrom ? f.dateTo : toApiDate(d);
    if (df.compareTo(dt) > 0) {
      // Meniru min/max input date web: geser sisi satunya.
      if (isFrom) {
        dt = df;
      } else {
        df = dt;
      }
    }
    ref.read(dbrFilterProvider.notifier).apply(dateFrom: df, dateTo: dt);
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(dbrFilterProvider);
    final recAsync = ref.watch(dbrRecordsProvider);
    final codesAsync = ref.watch(dbrCodesProvider);
    final codeList = switch (codesAsync) {
      AsyncData(:final value) => value,
      _ => const <String>[],
    };

    final pages = recAsync.when(
      data: (r) => (r.total / dbrPageSize).ceil().clamp(1, 1 << 30),
      loading: () => 1,
      error: (_, __) => 1,
    );

    return AppScaffold(
      title: 'DBR Breakdown',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(fmtDate(f.dateFrom)),
                ),
                const Text('–'),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(fmtDate(f.dateTo)),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _cn,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'C/N cth TL960',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: f.code.isEmpty ? '' : (codeList.contains(f.code) || f.code == '__EMPTY__' ? f.code : ''),
                  hint: const Text('Code: semua'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Code: semua')),
                    const DropdownMenuItem(value: '__EMPTY__', child: Text('Code: (kosong)')),
                    for (final c in codeList) DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => ref
                      .read(dbrFilterProvider.notifier)
                      .apply(code: v ?? ''),
                ),
                FilledButton(
                  onPressed: () => ref.read(dbrFilterProvider.notifier).apply(
                        cn: _cn.text.trim(),
                        code: f.code,
                      ),
                  child: const Text('Tampilkan'),
                ),
                FilterChip(
                  label: const Text('Sembunyikan CONTINUE'),
                  selected: f.hideContinue,
                  onSelected: (v) =>
                      ref.read(dbrFilterProvider.notifier).setHideContinue(v),
                ),
              ],
            ),
          ),
          Expanded(
            child: recAsync.when(
              data: (res) {
                final shown = f.hideContinue
                    ? res.rows.where((r) => !r.isContinue).toList()
                    : res.rows;
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
                          ref.invalidate(dbrRecordsProvider);
                          await ref.read(dbrRecordsProvider.future);
                        },
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: [
                                for (final c in _cols) DataColumn(label: Text(c.$2)),
                              ],
                              rows: [
                                for (final r in shown)
                                  DataRow(
                                    color: r.isContinue
                                        ? WidgetStatePropertyAll(
                                            Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.5),
                                          )
                                        : null,
                                    cells: [
                                      for (final c in _cols)
                                        DataCell(Text(_cell(r, c.$1))),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (shown.isEmpty)
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
                                    .read(dbrFilterProvider.notifier)
                                    .setPage(res.page - 1),
                            child: const Text('‹ Prev'),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Halaman ${res.page} dari $pages'),
                          ),
                          OutlinedButton(
                            onPressed: res.page >= pages
                                ? null
                                : () => ref
                                    .read(dbrFilterProvider.notifier)
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
                onRetry: () => ref.invalidate(dbrRecordsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
