import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;
import 'package:mte_data_center/src/core/utils/date_fmt.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';

import '../data/safety_api.dart';
import '../domain/safety_models.dart';
import 'safety_providers.dart';
import 'safety_widgets.dart';

const _compLabels = ['6PAS', 'Doa', 'APD', 'Stretch', 'Housekeeping', 'Alat', 'Prosedur'];

/// Tab Bomak: filter bulan/section/cari + Sync + salin WA + tabel +
/// cakupan + pengecualian. Meniru SafetyPage mode bomak.
class BomakView extends ConsumerStatefulWidget {
  const BomakView({super.key});

  @override
  ConsumerState<BomakView> createState() => _BomakViewState();
}

class _BomakViewState extends ConsumerState<BomakView> {
  late final TextEditingController _q;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _q = TextEditingController(text: ref.read(safetyFilterProvider).q);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _doSync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final r = await ref.read(safetyApiProvider).sync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Sinkron selesai: ${r.ok}/${r.fetched} baris${r.fail > 0 ? ', gagal ${r.fail}' : ''}'),
        ));
      }
      invalidateSafety(ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _copyWA() async {
    final f = ref.read(safetyFilterProvider);
    try {
      final rows = await ref.read(safetyApiProvider).exportRows(
            dateFrom: monthStart(f.year, f.month),
            dateTo: monthEnd(f.year, f.month),
            section: f.sec.isEmpty ? null : f.sec,
            search: f.q.isEmpty ? null : f.q,
          );
      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tidak ada data untuk disalin.')));
        }
        return;
      }
      final sync = await ref.read(safetyApiProvider).latestSync();
      final syncD = ddmmyyyy(sync?.finishedAt?.substring(0, 10));
      await Clipboard.setData(ClipboardData(
        text: buildBomakWaText(section: f.sec, rows: rows, syncDate: syncD),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tersalin, siap paste di WA.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(safetyFilterProvider);
    final rowsAsync = ref.watch(bomakRowsProvider);
    final syncAsync = ref.watch(bomakSyncProvider);
    final canSync = ref.watch(authProvider).can('bomak', 'add');
    final notifier = ref.read(safetyFilterProvider.notifier);
    final sections = switch (ref.watch(bomakCoverageProvider)) {
      AsyncData(:final value) => value.sections,
      _ => const <String>[],
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                      onPressed: () => notifier.shiftMonth(-1),
                      child: const Text('‹')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(monthTitle(f.year, f.month),
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  OutlinedButton(
                      onPressed: () => notifier.shiftMonth(1),
                      child: const Text('›')),
                ],
              ),
              DropdownButton<String>(
                value: sections.contains(f.sec) ? f.sec : '',
                hint: const Text('Section: semua'),
                items: [
                  const DropdownMenuItem(
                      value: '', child: Text('Section: semua')),
                  for (final s in sections)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => notifier.apply(sec: v ?? ''),
              ),
              FilledButton(
                  onPressed: () => notifier.apply(),
                  child: const Text('Tampilkan')),
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _q,
                  decoration: const InputDecoration(
                    labelText: 'Cari mekanik/pengawas/NRP',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              FilledButton(
                  onPressed: () => notifier.apply(q: _q.text.trim()),
                  child: const Text('Cari')),
              if (canSync)
                OutlinedButton(
                  onPressed: _syncing ? null : _doSync,
                  child: Text(_syncing ? 'Menyinkron...' : 'Sync'),
                ),
              IconButton.filledTonal(
                tooltip: 'Salin untuk WA',
                style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white),
                icon: const Text('WA',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _copyWA,
              ),
            ],
          ),
        ),
        syncAsync.when(
          data: (s) => s == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Sync terakhir: ${fmtDT(s.finishedAt)} • ok ${s.okRows ?? '-'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        Expanded(
          child: rowsAsync.when(
            data: (res) => _BomakBody(res: res),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(bomakRowsProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _BomakBody extends ConsumerWidget {
  final ({int total, int page, List<SafetyRow> rows}) res;
  const _BomakBody({required this.res});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final covAsync = ref.watch(bomakCoverageProvider);
    return RefreshIndicator(
      onRefresh: () async {
        invalidateSafety(ref);
        await ref.read(bomakRowsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          covAsync.when(
            data: (c) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatChip(
                    label: 'Section',
                    value:
                        '${c.coverage.where((e) => e.n > 0).length}/${c.sections.length}'),
                StatChip(label: 'Respons', value: '${c.compliance.total}'),
                StatChip(
                    label: 'P6 kosong',
                    value: '${c.compliance.p6Empty}'),
                StatChip(
                    label: 'FU kosong',
                    value: '${c.compliance.fuEmpty}'),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Tanggal')),
                  DataColumn(label: Text('Pengawas')),
                  DataColumn(label: Text('Mekanik')),
                  DataColumn(label: Text('Grade')),
                  DataColumn(label: Text('Section')),
                  DataColumn(label: Text('P1')),
                  DataColumn(label: Text('P2')),
                  DataColumn(label: Text('P3')),
                  DataColumn(label: Text('P4')),
                  DataColumn(label: Text('P5')),
                  DataColumn(label: Text('Temuan')),
                  DataColumn(label: Text('Vlog')),
                  DataColumn(label: Text('Area / Job')),
                ],
                rows: [
                  for (final r in res.rows)
                    DataRow(cells: [
                      DataCell(Text(fmtDT(r.submittedAt))),
                      DataCell(Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shortName(r.pengawasNama).isEmpty
                              ? '-'
                              : shortName(r.pengawasNama)),
                          Text(r.pengawasNrp ?? '',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      )),
                      DataCell(Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shortName(r.mekanikNama).isEmpty
                              ? '-'
                              : shortName(r.mekanikNama)),
                          Text(r.mekanikNrp ?? '',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      )),
                      DataCell(Text(r.grade ?? '-')),
                      DataCell(Text(r.section ?? '-')),
                      DataCell(OkBadge(
                          good: r.p1Ok, short: '1', title: 'P1 doa')),
                      DataCell(OkBadge(
                          good: r.p2Ok,
                          short: '2',
                          title: 'P2 APD+stretching')),
                      DataCell(OkBadge(
                          good: r.p3Ok,
                          short: '3',
                          title: 'P3 housekeeping')),
                      DataCell(OkBadge(
                          good: r.p4Ok, short: '4', title: 'P4 alat')),
                      DataCell(OkBadge(
                          good: r.p5Ok,
                          short: '5',
                          title: 'P5 prosedur')),
                      DataCell(ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: 180),
                        child: Text(
                            r.temuan.isEmpty ? '-' : r.temuan,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      )),
                      DataCell(Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DriveThumb(
                              fileId: r.vlogFile, label: 'vlog'),
                          if ((r.vlogDesc ?? '').isNotEmpty)
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxWidth: 140),
                              child: Text(r.vlogDesc!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall),
                            ),
                        ],
                      )),
                      DataCell(Text(
                          r.areaJob.isEmpty ? '-' : r.areaJob)),
                    ]),
                ],
              ),
            ),
          ),
          if (res.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Tidak ada data.')),
            ),
          PagerBar(
            page: res.page,
            total: res.total,
            pageSize: 20,
            onPage: (p) =>
                ref.read(safetyFilterProvider.notifier).setPage(p),
          ),
          covAsync.when(
            data: (c) => CoverageCard(
              title: 'Cakupan per section — siapa sudah muncul bulan ini',
              headers: const [
                'Section',
                'Respons',
                'Mekanik',
                'Pengawas',
                'Hari aktif',
                'Terakhir'
              ],
              rows: [
                for (final s in c.sections)
                  () {
                    final m = {
                      for (final e in c.coverage) e.section ?? '': e
                    }[s];
                    final empty = m == null || m.n == 0;
                    return CovCells(
                      dim: empty,
                      cells: [
                        empty ? '$s — belum ada data' : s,
                        '${m?.n ?? 0}',
                        '${m?.mekanik ?? 0}',
                        '${m?.pengawas ?? 0}',
                        '${m?.hari ?? 0}',
                        m?.terakhir != null
                            ? fmtDT(m!.terakhir)
                            : '-',
                      ],
                      boldFirst: true,
                    );
                  }(),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          covAsync.when(
            data: (c) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pengecualian per poin (perlu perhatian)',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _compLabels.length; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: (c.compliance.issues[i] > 0
                                      ? Colors.red
                                      : Colors.green)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_compLabels[i]}: ${c.compliance.issues[i]}',
                              style: TextStyle(
                                color: c.compliance.issues[i] > 0
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
