import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_fmt.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../data/ssab_api.dart';
import '../domain/ssab_models.dart';
import 'ssab_providers.dart';

final _nfmt = NumberFormat.decimalPattern('id_ID');

/// Angka ribuan locale id (meniru fmtNum web SsAb.tsx).
String fmtNum(num? v) => v == null ? '-' : _nfmt.format(v);

/// Rupiah ringkas sama gaya web fmtRp: T / M / jt / rb.
String fmtRpShort(num? v) {
  final n = (v ?? 0).abs().toDouble();
  String dec(double x, int d) => x.toStringAsFixed(d).replaceAll('.', ',');
  if (n >= 1e12) return 'Rp ${dec(n / 1e12, 2)} T';
  if (n >= 1e9) return 'Rp ${dec(n / 1e9, 2)} M';
  if (n >= 1e6) return 'Rp ${dec(n / 1e6, 1)} jt';
  if (n >= 1e3) return 'Rp ${(n / 1e3).toStringAsFixed(0)} rb';
  return 'Rp ${n.toInt()}';
}

/// Title Case per kata (web titleName): "rachmad r." -> "Rachmad R.".
String titleName(String? v) => (v ?? '')
    .trim()
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w
        .split('-')
        .map((s) => s.isEmpty
            ? s
            : s.substring(0, 1).toUpperCase() + s.substring(1).toLowerCase())
        .join('-'))
    .join(' ');

/// Nama bulan Indonesia untuk kalender (web MONTHS).
const monthNames = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String monthLabel(int m) => (m >= 1 && m <= 12) ? monthNames[m - 1] : '$m';

/// Tanggal dd/MM/yyyy, '-' bila kosong (web fmtDate).
String fmtDateDash(String? v) =>
    (v == null || v.trim().isEmpty) ? '-' : fmtDate(v);

/// Filter tabel waiting ala web: substring manajemen tanpa peduli besar-kecil.
List<SsAbWaiting> filterWaitingByManager(List<SsAbWaiting> rows, String pick) {
  if (pick.isEmpty) return rows;
  final u = pick.toUpperCase();
  return rows
      .where((r) => (r.management ?? '').toUpperCase().contains(u))
      .toList();
}

/// Label chip manajemen: kata pertama Title Case + "…" (web `titleName(first)…`).
String managerChipLabel(String manager) {
  final first = manager
      .trim()
      .split(RegExp(r'\s+'))
      .firstWhere((s) => s.isNotEmpty, orElse: () => '');
  return first.isEmpty ? '…' : '${titleName(first)}…';
}

const _brand = Color(0xFF465FFF);
const _cPurple = Color(0xFF7F56D9);
const _cGreen = Color(0xFF12B76A);
const _cOrange = Color(0xFFF79009);
const _cGray = Color(0xFF98A2B3);

Color _gradeColor(String? g) => switch (g) {
      'A' => _cPurple,
      'B' => Color(0xFF465FFF),
      _ => _cGray,
    };

/// Halaman SS AB — dashboard SS Grade A & B approved tahun berjalan +
/// kalender 12 bulan + detail + waiting approval PM (paritas web SsAb.tsx).
class SsabPage extends ConsumerStatefulWidget {
  const SsabPage({super.key});

  @override
  ConsumerState<SsabPage> createState() => _SsabPageState();
}

class _SsabPageState extends ConsumerState<SsabPage> {
  int _page = 1;
  int _pageSize = 25;
  String _waitPick = '';
  bool _exporting = false;
  bool _exportingWait = false;

  Future<void> _saveFile(String name, Future<Uint8List> Function() fetch) async {
    final bytes = await fetch();
    final path = await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(path == null ? 'Export dibatalkan.' : 'CSV tersimpan.')));
  }

  Future<void> _exportSsAb() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final year = ref.read(ssabYearProvider);
      await _saveFile(
        'ss_ab_${year}_${toApiDate(DateTime.now())}.csv',
        () => ref.read(ssabApiProvider).exportCsv(year: year),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportWaiting() async {
    if (_exportingWait) return;
    setState(() => _exportingWait = true);
    try {
      await _saveFile(
        'ss_waiting_pm_${toApiDate(DateTime.now())}.csv',
        () => ref.read(ssabApiProvider).exportWaitingCsv(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _exportingWait = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(ssabDataProvider);
    final d = dataAsync.value;
    return AppScaffold(
      title: 'SS AB',
      body: d == null
          ? (dataAsync.hasError
              ? ErrorView(
                  message: dataAsync.error.toString(),
                  onRetry: () => ref.invalidate(ssabDataProvider),
                )
              : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(ssabDataProvider);
                await ref.read(ssabDataProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _yearRow(d),
                  const SizedBox(height: 8),
                  _kpiGrid(d),
                  const SizedBox(height: 12),
                  _calendarCard(d),
                  if (d.byDept.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _deptCard(d),
                  ],
                  const SizedBox(height: 12),
                  _recordsCard(d),
                  const SizedBox(height: 12),
                  _waitingCard(d),
                ],
              ),
            ),
    );
  }

  // ── Filter tahun ────────────────────────────────────────────────
  Widget _yearRow(SsAbResp d) {
    final thisYear = DateTime.now().year;
    final years = d.years.isEmpty
        ? [thisYear]
        : (d.years.contains(thisYear) ? d.years : [thisYear, ...d.years]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Tahun', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: years.contains(d.year) ? d.year : years.first,
              items: [
                for (final y in years)
                  DropdownMenuItem(value: y, child: Text('$y')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _page = 1);
                ref.read(ssabYearProvider.notifier).set(v);
              },
            ),
          ],
        ),
        Text(
          'SS Grade A & B berstatus approved · 1 Januari – '
          '${fmtDateDash(d.end)} ${d.year}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  // ── KPI 6 kartu ─────────────────────────────────────────────────
  Widget _kpiGrid(SsAbResp d) {
    final k = d.kpi;
    final pctA = k.total > 0 ? '${(k.gradeA / k.total * 100).round()}% dari AB' : '0% dari AB';
    final pctB = k.total > 0 ? '${(k.gradeB / k.total * 100).round()}% dari AB' : '0% dari AB';
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.55,
      children: [
        _KpiCard(
          label: 'Total SS AB',
          value: fmtNum(k.total),
          color: _brand,
          sub: 'approved 1 Jan – ${fmtDateDash(d.end)}',
        ),
        _KpiCard(label: 'Grade A', value: fmtNum(k.gradeA), color: _cPurple, sub: pctA),
        _KpiCard(label: 'Grade B', value: fmtNum(k.gradeB), color: _brand, sub: pctB),
        _KpiCard(
          label: 'Total Reward',
          value: fmtRpShort(k.reward),
          color: _cGreen,
          sub: 'Rp ${fmtNum(k.reward)}',
        ),
        _KpiCard(
          label: 'Manfaat Financial',
          value: fmtRpShort(k.manfaat),
          color: _cOrange,
          sub: 'akumulasi SS AB',
        ),
        _KpiCard(
          label: 'Pencetus Unik',
          value: fmtNum(k.pencetus),
          color: _cGray,
          sub: k.pencetus > 0
              ? '± ${(k.total / k.pencetus).toStringAsFixed(1)} SS/orang'
              : '-',
        ),
      ],
    );
  }

  // ── Kalender 12 bulan ───────────────────────────────────────────
  Widget _calendarCard(SsAbResp d) {
    final now = DateTime.now();
    final thisYear = now.year;
    final maxMonth = d.calendar.fold<int>(1, (a, m) => m.total > a ? m.total : a);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kalender SS AB Approved — ${d.year}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(
              'Angka = jumlah SS Grade A & B yang approved (dinilai) pada bulan tersebut.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.92,
              children: [
                for (final m in d.calendar) _monthCell(m, d.year, thisYear, now.month, maxMonth),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthCell(SsAbMonth m, int year, int thisYear, int nowMonth, int maxMonth) {
    final isNow = m.month == nowMonth && year == thisYear;
    final future = year == thisYear && m.month > nowMonth;
    final theme = Theme.of(context);
    final ratio = m.total > 0 ? 0.06 + 0.16 * (m.total / maxMonth) : 0.0;
    final bg = m.total > 0
        ? Color.lerp(theme.colorScheme.surface, _brand, ratio)
        : theme.colorScheme.surface;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNow ? _brand : theme.dividerColor.withValues(alpha: 0.5),
          width: isNow ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthLabel(m.month),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: future ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          Text(
            m.total > 0 ? fmtNum(m.total) : (future ? '–' : '0'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: m.total > 0
                  ? _brand
                  : (future ? Colors.grey.shade400 : Colors.grey.shade300),
            ),
          ),
          Text('A ${fmtNum(m.a)} · B ${fmtNum(m.b)}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          if (m.reward > 0)
            Text(fmtRpShort(m.reward),
                style: const TextStyle(fontSize: 10, color: _cGreen)),
        ],
      ),
    );
  }

  // ── Breakdown per dept ──────────────────────────────────────────
  Widget _deptCard(SsAbResp d) {
    final maxDept = d.byDept.fold<int>(1, (a, x) => x.total > a ? x.total : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Per Dept',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 14,
                horizontalMargin: 8,
                headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                dataTextStyle: const TextStyle(fontSize: 11),
                columns: const [
                  DataColumn(label: Text('Dept')),
                  DataColumn(label: Text('Total'), numeric: true),
                  DataColumn(label: Text('Grade A'), numeric: true),
                  DataColumn(label: Text('Grade B'), numeric: true),
                  DataColumn(label: Text('Proporsi')),
                ],
                rows: [
                  for (final x in d.byDept)
                    DataRow(cells: [
                      DataCell(SizedBox(
                        width: 150,
                        child: Text(x.dept, overflow: TextOverflow.ellipsis),
                      )),
                      DataCell(Text(fmtNum(x.total),
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(fmtNum(x.a),
                          style: const TextStyle(color: _cPurple))),
                      DataCell(Text(fmtNum(x.b),
                          style: const TextStyle(color: _brand))),
                      DataCell(SizedBox(
                        width: 90,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: x.total / maxDept,
                            minHeight: 8,
                            backgroundColor:
                                Theme.of(context).dividerColor.withValues(alpha: 0.3),
                          ),
                        ),
                      )),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Detail SS AB + pagination + export ──────────────────────────
  Widget _recordsCard(SsAbResp d) {
    final recs = d.records;
    final totalPages = (recs.length / _pageSize).ceil().clamp(1, 1 << 31);
    final page = _page.clamp(1, totalPages);
    final pageRows =
        recs.skip((page - 1) * _pageSize).take(_pageSize).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Detail SS AB',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  '1 Jan – ${fmtDateDash(d.end)} ${d.year} · ${fmtNum(recs.length)} baris'
                  '${recs.length >= 500 ? ' (500 terbaru)' : ''}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
                OutlinedButton.icon(
                  onPressed: _exporting ? null : _exportSsAb,
                  icon: const Icon(Icons.download, size: 16),
                  label: Text(_exporting ? 'Mengunduh...' : 'Export CSV',
                      style: const TextStyle(fontSize: 12)),
                ),
                DropdownButton<int>(
                  value: _pageSize,
                  items: [
                    for (final n in const [25, 50, 100, 200])
                      DropdownMenuItem(value: n, child: Text('$n / halaman', style: const TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _pageSize = v;
                      _page = 1;
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Halaman pertama',
                  visualDensity: VisualDensity.compact,
                  onPressed: page <= 1 ? null : () => setState(() => _page = 1),
                  icon: const Icon(Icons.first_page),
                ),
                IconButton(
                  tooltip: 'Sebelumnya',
                  visualDensity: VisualDensity.compact,
                  onPressed: page <= 1 ? null : () => setState(() => _page = page - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('$page / $totalPages',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                IconButton(
                  tooltip: 'Berikutnya',
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      page >= totalPages ? null : () => setState(() => _page = page + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  tooltip: 'Halaman terakhir',
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      page >= totalPages ? null : () => setState(() => _page = totalPages),
                  icon: const Icon(Icons.last_page),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (pageRows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Tidak ada SS Grade A/B approved pada rentang ini.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 14,
                  horizontalMargin: 8,
                  headingTextStyle:
                      const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  dataTextStyle: const TextStyle(fontSize: 11),
                  columns: const [
                    DataColumn(label: Text('No SS')),
                    DataColumn(label: Text('Tgl Menilai')),
                    DataColumn(label: Text('Judul')),
                    DataColumn(label: Text('Pencetus')),
                    DataColumn(label: Text('Dept')),
                    DataColumn(label: Text('Grade')),
                    DataColumn(label: Text('Reward'), numeric: true),
                    DataColumn(label: Text('Manfaat Fin'), numeric: true),
                    DataColumn(label: Text('Penilai')),
                  ],
                  rows: [
                    for (final r in pageRows)
                      DataRow(cells: [
                        DataCell(Text(r.noSs,
                            style: const TextStyle(fontFamily: 'monospace'))),
                        DataCell(Text(fmtDateDash(r.tglMenilai))),
                        DataCell(SizedBox(
                          width: 200,
                          child: Text(r.judul ?? '-',
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        )),
                        DataCell(SizedBox(
                          width: 140,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(titleName(r.pencetus).isEmpty
                                  ? '-'
                                  : titleName(r.pencetus),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              if ((r.nrp ?? '').isNotEmpty)
                                Text(r.nrp!,
                                    style: TextStyle(
                                        fontSize: 9, color: Colors.grey.shade500)),
                            ],
                          ),
                        )),
                        DataCell(Text(r.dept ?? '-')),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _gradeColor(r.grade),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(r.grade ?? '-',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        )),
                        DataCell(Text(r.reward > 0 ? fmtRpShort(r.reward) : '-')),
                        DataCell(Text((r.manfaatFin ?? 0) > 0
                            ? fmtRpShort(r.manfaatFin)
                            : '-')),
                        DataCell(SizedBox(
                          width: 130,
                          child: Text(
                            titleName(r.dinilaiOleh).isEmpty
                                ? '-'
                                : titleName(r.dinilaiOleh),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                      ]),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Waiting approval PM + filter chips + export ─────────────────
  Widget _waitingCard(SsAbResp d) {
    final waitRows = filterWaitingByManager(d.waiting, _waitPick);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Menunggu Penilaian oleh PM',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  'SS outstanding hanya dengan status "Menunggu Penilaian oleh PM" · '
                  '${fmtNum(waitRows.length)} baris',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                OutlinedButton.icon(
                  onPressed: _exportingWait ? null : _exportWaiting,
                  icon: const Icon(Icons.download, size: 16),
                  label: Text(_exportingWait ? 'Mengunduh...' : 'Export CSV',
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                FilterChip(
                  label: Text('Semua (${fmtNum(d.waiting.length)})',
                      style: const TextStyle(fontSize: 11)),
                  selected: _waitPick.isEmpty,
                  onSelected: (_) => setState(() => _waitPick = ''),
                ),
                for (final w in d.waitingPerManager)
                  Tooltip(
                    message: w.manager,
                    child: FilterChip(
                      label: Text('${managerChipLabel(w.manager)} (${fmtNum(w.total)})',
                          style: const TextStyle(fontSize: 11)),
                      selected: _waitPick == w.manager,
                      onSelected: (_) => setState(() =>
                          _waitPick = _waitPick == w.manager ? '' : w.manager),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (waitRows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Tidak ada SS waiting approval pada manajemen terpilih.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 14,
                  horizontalMargin: 8,
                  headingTextStyle:
                      const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  dataTextStyle: const TextStyle(fontSize: 11),
                  columns: const [
                    DataColumn(label: Text('No SS')),
                    DataColumn(label: Text('Tgl Laporan')),
                    DataColumn(label: Text('Judul')),
                    DataColumn(label: Text('Pencetus')),
                    DataColumn(label: Text('Dept')),
                    DataColumn(label: Text('Menunggu Sejak')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Manajemen')),
                  ],
                  rows: [
                    for (final r in waitRows)
                      DataRow(cells: [
                        DataCell(Text(r.noSs,
                            style: const TextStyle(fontFamily: 'monospace'))),
                        DataCell(Text(fmtDateDash(r.tglLaporan))),
                        DataCell(SizedBox(
                          width: 200,
                          child: Text(r.judul ?? '-',
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        )),
                        DataCell(SizedBox(
                          width: 140,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(titleName(r.pencetus).isEmpty
                                  ? '-'
                                  : titleName(r.pencetus),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              if ((r.nrp ?? '').isNotEmpty)
                                Text(r.nrp!,
                                    style: TextStyle(
                                        fontSize: 9, color: Colors.grey.shade500)),
                            ],
                          ),
                        )),
                        DataCell(Text(r.dept ?? '-')),
                        DataCell(Text(fmtDateDash(r.outstandingAt))),
                        DataCell((r.statusSs ?? '').isEmpty
                            ? const Text('-')
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF0C7),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  r.statusSs!,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFB54708)),
                                ),
                              )),
                        DataCell(SizedBox(
                          width: 180,
                          child: Text(
                            (r.management ?? '').isEmpty
                                ? '-'
                                : titleName(r.management),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                      ]),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String sub;
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
