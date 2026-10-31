import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_fmt.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../domain/ss_models.dart';
import 'ss_providers.dart';

final _nfmt = NumberFormat.decimalPattern('id_ID');
final _rfmt = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

String fmtNum(num? v) => v == null ? '-' : _nfmt.format(v);
String fmtRupiah(num? v) => v == null ? '-' : _rfmt.format(v);

/// Singkatan nama management (meniru abbrName di Ss.tsx).
String abbrName(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '-';
  if (parts.length == 1) return parts[0];
  return '${parts[0]} ${parts.sublist(1).map((p) => p[0].toUpperCase()).join()}';
}

/// Warna grafik mengikuti web Ss.tsx.
const _cApproved = Color(0xFF12B76A);
const _cMenunggu = Color(0xFFF79009);
const _cTarget = Color(0xFFD1D5DB);
const _cAktual = Color(0xFF3B82F6);
const _cLaporan = Color(0xFF465FFF);

class SsPage extends ConsumerStatefulWidget {
  const SsPage({super.key});

  @override
  ConsumerState<SsPage> createState() => _SsPageState();
}

class _SsPageState extends ConsumerState<SsPage> {
  /// 'hari' | 'bulan' — bucket grafik "Jumlah SS per Tanggal Laporan".
  String _bucket = 'hari';

  Future<void> _pickDate({required bool isStart}) async {
    final f = ref.read(ssFilterProvider);
    final current = DateTime.tryParse((isStart ? f.start : f.end) ?? '') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    final notifier = ref.read(ssFilterProvider.notifier);
    if (isStart) {
      var start = toApiDate(picked);
      var end = f.end ?? toApiDate(DateTime.now());
      if (start.compareTo(end) > 0) end = start;
      notifier.apply(start: start, end: end);
    } else {
      var end = toApiDate(picked);
      var start = f.start ?? toApiDate(DateTime.now());
      if (end.compareTo(start) < 0) start = end;
      notifier.apply(start: start, end: end);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(ssKpiProvider);
    ref.invalidate(ssTargetCrewProvider);
    ref.invalidate(ssDailyTrendProvider);
    ref.invalidate(ssMonthlyTrendProvider);
    ref.invalidate(ssRecordsProvider);
    await ref.read(ssKpiProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(ssFilterProvider);
    final kpiAsync = ref.watch(ssKpiProvider);
    final targetAsync = ref.watch(ssTargetCrewProvider);
    final trendAsync = ref.watch(_bucket == 'hari' ? ssDailyTrendProvider : ssMonthlyTrendProvider);

    return AppScaffold(
      title: 'Suggestion System',
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          icon: const Icon(Icons.refresh),
          onPressed: _refresh,
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // ---------- Filter ----------
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: true),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(fmtDate(f.start)),
                ),
                const Text('–'),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(isStart: false),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(fmtDate(f.end)),
                ),
                DropdownButton<String>(
                  value: f.dateBasis,
                  items: const [
                    DropdownMenuItem(value: 'menilai', child: Text('Tanggal Menilai')),
                    DropdownMenuItem(value: 'laporan', child: Text('Tanggal Laporan')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(ssFilterProvider.notifier).apply(dateBasis: v);
                    }
                  },
                ),
                OutlinedButton(
                  onPressed: () => ref.read(ssFilterProvider.notifier).reset(),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ---------- KPI ----------
            kpiAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(ssKpiProvider),
              ),
              data: (kpi) => _KpiGrid(kpi: kpi),
            ),
            const SizedBox(height: 16),

            // ---------- Jumlah SS per Tanggal Laporan ----------
            trendAsync.when(
              loading: () => const _LoadingCard(height: 300),
              error: (e, _) => Card(
                child: ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(
                    _bucket == 'hari' ? ssDailyTrendProvider : ssMonthlyTrendProvider,
                  ),
                ),
              ),
              data: (rows) => _DailyCard(
                rows: _bucket == 'hari'
                    ? rows.where((r) => r.laporan > 0).toList()
                    : rows,
                bucket: _bucket,
                onBucketChanged: (v) => setState(() => _bucket = v),
              ),
            ),
            const SizedBox(height: 16),

            // ---------- Target / Status / Open Approval ----------
            targetAsync.when(
              loading: () => const _LoadingCard(height: 300),
              error: (e, _) => Card(
                child: ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(ssTargetCrewProvider),
                ),
              ),
              data: (t) => Column(
                children: [
                  _TargetCrewCard(t: t),
                  const SizedBox(height: 16),
                  _StatusCard(t: t),
                  const SizedBox(height: 16),
                  _OpenApprovalCard(t: t),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ---------- Records ----------
            const _RecordsSection(),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// KPI
// =====================================================================
class _KpiGrid extends StatelessWidget {
  final SsKpi kpi;
  const _KpiGrid({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, Color)>[
      ('Total SS', fmtNum(kpi.total), const Color(0xFF465FFF)),
      ('Outstanding', fmtNum(kpi.outstanding), _cMenunggu),
      ('Pending', fmtNum(kpi.pending), const Color(0xFFF04438)),
      ('Total Reward', fmtRupiah(kpi.reward), _cApproved),
      ('Manfaat Financial', fmtRupiah(kpi.manfaat), const Color(0xFF7A5AF8)),
      ('Pencetus Unik', fmtNum(kpi.pencetus), const Color(0xFF0BA5EC)),
      ('Grade A', fmtNum(kpi.gradeA), _cApproved),
      ('Grade A+B', fmtNum(kpi.gradeAb), const Color(0xFF12B76A)),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 560 ? 3 : 2);
        final w = (c.maxWidth - 8 * (cols - 1)) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final it in items)
              SizedBox(
                width: w,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.$1,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          it.$2,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: it.$3,
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// =====================================================================
// Jumlah SS per Tanggal Laporan
// =====================================================================
class _DailyCard extends StatelessWidget {
  final List<SsTrendPoint> rows;
  final String bucket;
  final ValueChanged<String> onBucketChanged;

  const _DailyCard({
    required this.rows,
    required this.bucket,
    required this.onBucketChanged,
  });

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<int>(0, (a, b) => a + b.laporan);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jumlah SS per Tanggal Laporan',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${fmtNum(total)} SS pada ${fmtNum(rows.length)} '
                        '${bucket == 'hari' ? 'tanggal laporan' : 'bulan'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(value: 'hari', label: Text('Hari')),
                    ButtonSegment(value: 'bulan', label: Text('Bulan')),
                  ],
                  selected: {bucket},
                  onSelectionChanged: (s) => onBucketChanged(s.first),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Tidak ada SS pada rentang tanggal ini.')),
              )
            else ...[
              SizedBox(
                height: 260,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (g, _, rod, __) {
                          final p = rows[g.x].period;
                          return BarTooltipItem(
                            '$p\n${fmtNum(rod.toY.toInt())} SS',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (v, _) => Text(
                            fmtNum(v.toInt()),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: rows.length <= 31,
                          reservedSize: 46,
                          interval: rows.length > 60 ? (rows.length / 12).ceilToDouble() : 1,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= rows.length) {
                              return const SizedBox.shrink();
                            }
                            final p = rows[i].period;
                            final label = bucket == 'hari' && p.length == 10
                                ? '${p.substring(8, 10)}/${p.substring(5, 7)}'
                                : p;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Transform.rotate(
                                angle: -0.6,
                                child: Text(label, style: const TextStyle(fontSize: 9)),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < rows.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: rows[i].laporan.toDouble(),
                              width: rows.length > 20 ? 6 : 12,
                              color: _cLaporan,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Target SS per Crew
// =====================================================================
class _TargetCrewCard extends StatelessWidget {
  final SsTargetCrewResp t;
  const _TargetCrewCard({required this.t});

  @override
  Widget build(BuildContext context) {
    final rows = t.data;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target SS per Crew — ${fmtNum(t.multiplier)} SS per NRP',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              'Aktual ${fmtNum(t.totalAktual)} dari target ${fmtNum(t.totalTarget)} SS',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Belum ada data crew.')),
              )
            else ...[
              SizedBox(
                height: 260,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (g, _, rod, i) {
                          final r = rows[g.x];
                          final label = i == 0 ? 'Target' : 'Aktual';
                          return BarTooltipItem(
                            '${r.crew}\n$label: ${fmtNum(rod.toY.toInt())} SS',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (v, _) => Text(
                            fmtNum(v.toInt()),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 56,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= rows.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Transform.rotate(
                                angle: -0.6,
                                child: Text(
                                  rows[i].crew,
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < rows.length; i++)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 3,
                          barRods: [
                            BarChartRodData(
                              toY: rows[i].target.toDouble(),
                              width: 8,
                              color: _cTarget,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                            BarChartRodData(
                              toY: rows[i].aktual.toDouble(),
                              width: 8,
                              color: _cAktual,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(color: _cTarget, label: 'Target'),
                  SizedBox(width: 16),
                  _LegendDot(color: _cAktual, label: 'Aktual'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Status Judul SS (donut)
// =====================================================================
class _StatusCard extends StatelessWidget {
  final SsTargetCrewResp t;
  const _StatusCard({required this.t});

  @override
  Widget build(BuildContext context) {
    final approved = t.approved;
    final menunggu = t.menunggu;
    final total = approved + menunggu;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status Judul SS', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              'Approved vs Menunggu Approval',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (total == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Tidak ada SS pada rentang tanggal ini.')),
              )
            else ...[
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 52,
                    startDegreeOffset: -90,
                    sections: [
                      PieChartSectionData(
                        value: approved.toDouble(),
                        title: '${(approved / total * 100).toStringAsFixed(1)}%',
                        color: _cApproved,
                        radius: 46,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      PieChartSectionData(
                        value: menunggu.toDouble(),
                        title: '${(menunggu / total * 100).toStringAsFixed(1)}%',
                        color: _cMenunggu,
                        radius: 46,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(color: _cApproved, label: 'Approved ${fmtNum(approved)}'),
                  const SizedBox(width: 16),
                  _LegendDot(color: _cMenunggu, label: 'Menunggu ${fmtNum(menunggu)}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Open Approval per Management
// =====================================================================
class _OpenApprovalCard extends StatelessWidget {
  final SsTargetCrewResp t;
  const _OpenApprovalCard({required this.t});

  @override
  Widget build(BuildContext context) {
    final rows = [...t.statusSsBreakdown]
      ..sort((a, b) => b.jumlah.compareTo(a.jumlah));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Open Approval per Management',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              'SS outstanding (belum dinilai) per management',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('Tidak ada judul SS outstanding pada rentang ini.'),
                ),
              )
            else ...[
              SizedBox(
                height: 240,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (g, _, rod, __) {
                          final r = rows[g.x];
                          return BarTooltipItem(
                            '${r.management}\n${fmtNum(rod.toY.toInt())} SS',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (v, _) => Text(
                            fmtNum(v.toInt()),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 56,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= rows.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Transform.rotate(
                                angle: -0.6,
                                child: Text(
                                  abbrName(rows[i].management),
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < rows.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: rows[i].jumlah.toDouble(),
                              width: 14,
                              color: _cMenunggu,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (final r in rows)
                    Text(
                      '${abbrName(r.management)}: ${fmtNum(r.jumlah)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Last update data: ${t.lastUpdate == null ? '-' : fmtDT(t.lastUpdate)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Records
// =====================================================================
class _RecordsSection extends ConsumerWidget {
  const _RecordsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ssRecordsProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detail SS (50 terbaru)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(ssRecordsProvider),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Tidak ada data SS pada filter ini.')),
                  );
                }
                return Column(
                  children: [
                    for (final r in rows)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          r.judul ?? r.noSs,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${r.noSs} • ${fmtDate(r.tglLaporan)} • '
                          '${r.pencetus ?? '-'} (${r.nrp ?? '-'}) • ${r.dept ?? '-'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              r.grade ?? '-',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              r.statusSs ?? '-',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Helper widget
// =====================================================================
class _LoadingCard extends StatelessWidget {
  final double height;
  const _LoadingCard({required this.height});

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: SizedBox(
          height: height,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
