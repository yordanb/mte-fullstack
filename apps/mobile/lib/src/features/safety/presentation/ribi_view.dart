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

/// Tab R1BI: filter bulan/section/risiko/cari + Sync + salin WA + tabel +
/// cakupan. Meniru RibiView (tombol Sync ikut izin `bomak.add` spt web).
class RibiViewTab extends ConsumerStatefulWidget {
  const RibiViewTab({super.key});

  @override
  ConsumerState<RibiViewTab> createState() => _RibiViewTabState();
}

class _RibiViewTabState extends ConsumerState<RibiViewTab> {
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
      final r = await ref.read(safetyApiProvider).ribiSync();
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
      final rows = await ref.read(safetyApiProvider).ribiExportRows(
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
      final sync = await ref.read(safetyApiProvider).ribiLatestSync();
      final syncD = ddmmyyyy(sync?.finishedAt?.substring(0, 10));
      await Clipboard.setData(ClipboardData(
        text: buildRibiWaText(section: f.sec, rows: rows, syncDate: syncD),
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
    final covAsync = ref.watch(ribiCoverageProvider);
    final rowsAsync = ref.watch(ribiRowsProvider);
    final syncAsync = ref.watch(ribiSyncProvider);
    final canSync = ref.watch(authProvider).can('bomak', 'add');
    final notifier = ref.read(safetyFilterProvider.notifier);
    final sections = switch (covAsync) {
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
              DropdownButton<String>(
                value: f.risk,
                hint: const Text('Risiko: semua'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Risiko: semua')),
                  DropdownMenuItem(
                      value: 'HIGH RISK', child: Text('HIGH RISK')),
                  DropdownMenuItem(
                      value: 'LOW RISK', child: Text('LOW RISK')),
                ],
                onChanged: (v) => notifier.apply(risk: v ?? ''),
              ),
              FilledButton(
                  onPressed: () => notifier.apply(),
                  child: const Text('Tampilkan')),
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _q,
                  decoration: const InputDecoration(
                    labelText: 'Cari nama/NRP/staff',
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
            data: (res) => RefreshIndicator(
              onRefresh: () async {
                invalidateSafety(ref);
                await ref.read(ribiRowsProvider.future);
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
                        StatChip(
                            label: 'Respons', value: '${c.total}'),
                        StatChip(
                          label: 'HIGH RISK',
                          value: '${c.high}',
                          valueColor: Colors.red,
                        ),
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
                          DataColumn(label: Text('Tgl R1BI')),
                          DataColumn(label: Text('Pekerja')),
                          DataColumn(label: Text('Jabatan')),
                          DataColumn(label: Text('Section')),
                          DataColumn(label: Text('Staff')),
                          DataColumn(label: Text('Risiko')),
                          DataColumn(label: Text('Lokasi / Job')),
                          DataColumn(label: Text('Bahaya')),
                          DataColumn(label: Text('Foto area')),
                          DataColumn(label: Text('Foto JSA')),
                        ],
                        rows: [
                          for (final r in res.rows)
                            DataRow(cells: [
                              DataCell(Text(ddmmyyyy(r.tanggal))),
                              DataCell(Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(shortName(r.nama).isEmpty
                                      ? '-'
                                      : shortName(r.nama)),
                                  Text(r.nrp ?? '',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ],
                              )),
                              DataCell(Text(r.jabatan ?? '-')),
                              DataCell(Text(r.section ?? '-')),
                              DataCell(Text(r.staffRibi ?? '-')),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (r.isHighRisk
                                          ? Colors.red
                                          : Colors.green)
                                      .withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Text(
                                  r.aktivitas ?? '-',
                                  style: TextStyle(
                                    color: r.isHighRisk
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )),
                              DataCell(Text(r.lokasiJob.isEmpty
                                  ? '-'
                                  : r.lokasiJob)),
                              DataCell(ConstrainedBox(
                                constraints: const BoxConstraints(
                                    maxWidth: 180),
                                child: Text(r.bahayaDesc ?? '-',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              )),
                              DataCell(DriveThumb(
                                  fileId: r.fotoAreaFile,
                                  label: 'foto area')),
                              DataCell(DriveThumb(
                                  fileId: r.fotoJsaFile,
                                  label: 'foto JSA')),
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
                    onPage: (p) => ref
                        .read(safetyFilterProvider.notifier)
                        .setPage(p),
                  ),
                  covAsync.when(
                    data: (c) => CoverageCard(
                      title:
                          'Cakupan per section — siapa sudah muncul bulan ini',
                      headers: const [
                        'Section',
                        'Respons',
                        'Pekerja',
                        'HIGH RISK',
                        'Hari aktif',
                        'Terakhir'
                      ],
                      rows: [
                        for (final s in c.sections)
                          () {
                            final m = {
                              for (final e in c.coverage)
                                e.section ?? '': e
                            }[s];
                            final empty = m == null || m.n == 0;
                            return CovCells(
                              dim: empty,
                              cells: [
                                empty ? '$s — belum ada data' : s,
                                '${m?.n ?? 0}',
                                '${m?.pekerja ?? 0}',
                                '${m?.high ?? 0}',
                                '${m?.hari ?? 0}',
                                m?.terakhir != null
                                    ? ddmmyyyy(m!.terakhir)
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
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(ribiRowsProvider),
            ),
          ),
        ),
      ],
    );
  }
}
