import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/utils/date_fmt.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';
import 'package:mte_data_center/src/features/dbr/presentation/dbr_providers.dart';

import '../domain/perf_models.dart';
import 'performance_providers.dart';

/// Warna grafik PERF_COLORS web (Performance.tsx:5).
const _chartColors = [
  Color(0xFF465FFF),
  Color(0xFF9CB878),
  Color(0xFFE6A23C),
  Color(0xFFE26D5C),
  Color(0xFF7B7FD4),
  Color(0xFF4FB0C6),
  Color(0xFF8A8A8A),
];

const _grans = [('day', 'Harian'), ('week', 'Mingguan'), ('month', 'Bulanan')];

/// Performance: kartu ringkasan + grafik frekuensi stacked bar per prefix
/// (fl_chart) + 4 Pareto. Meniru Performance.tsx (ApexCharts -> fl_chart).
class PerformancePage extends ConsumerStatefulWidget {
  const PerformancePage({super.key});

  @override
  ConsumerState<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends ConsumerState<PerformancePage> {
  late final TextEditingController _prefix;

  @override
  void initState() {
    super.initState();
    _prefix = TextEditingController(text: ref.read(perfFilterProvider).prefix);
  }

  @override
  void dispose() {
    _prefix.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final f = ref.read(perfFilterProvider);
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
      if (isFrom) {
        dt = df;
      } else {
        df = dt;
      }
    }
    ref.read(perfFilterProvider.notifier).apply(dateFrom: df, dateTo: dt);
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(perfFilterProvider);
    final statsAsync = ref.watch(perfStatsProvider);
    final codesAsync = ref.watch(dbrCodesProvider);
    final codeList = switch (codesAsync) {
      AsyncData(:final value) => value,
      _ => const <String>[],
    };

    return AppScaffold(
      title: 'Performance',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(perfStatsProvider);
          await ref.read(perfStatsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Wrap(
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
                DropdownButton<String>(
                  value: f.granularity,
                  items: [
                    for (final g in _grans) DropdownMenuItem(value: g.$1, child: Text(g.$2)),
                  ],
                  onChanged: (v) =>
                      ref.read(perfFilterProvider.notifier).apply(granularity: v),
                ),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _prefix,
                    maxLength: 2,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Prefix',
                      border: OutlineInputBorder(),
                      isDense: true,
                      counterText: '',
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: f.code.isEmpty
                      ? ''
                      : (codeList.contains(f.code) || f.code == '__EMPTY__' ? f.code : ''),
                  hint: const Text('Code: semua'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Code: semua')),
                    const DropdownMenuItem(value: '__EMPTY__', child: Text('Code: (kosong)')),
                    for (final c in codeList) DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) =>
                      ref.read(perfFilterProvider.notifier).apply(code: v ?? ''),
                ),
                FilledButton(
                  onPressed: () => ref.read(perfFilterProvider.notifier).apply(
                        prefix: _prefix.text.trim(),
                        code: f.code,
                      ),
                  child: const Text('Tampilkan'),
                ),
                FilterChip(
                  label: const Text('Kecualikan CONTINUE'),
                  selected: f.noCont,
                  onSelected: (v) =>
                      ref.read(perfFilterProvider.notifier).apply(noCont: v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            statsAsync.when(
              data: (st) => _Body(st: st, gran: f.granularity),
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(perfStatsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final PerfStats st;
  final String gran;
  const _Body({required this.st, required this.gran});

  @override
  Widget build(BuildContext context) {
    final s = st.summary;
    final cards = [
      ('Total breakdown', '${s.total}'),
      ('Unit terdampak', '${s.units}'),
      ('Hari aktif', '${s.days}'),
      ('Rata-rata / hari', s.avgPerDay),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (st.excludeContinue && st.excludedContinue > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${st.excludedContinue} baris CONTINUE dikecualikan — grafik menghitung kejadian breakdown, bukan hari downtime.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: cards.length,
          itemBuilder: (c, i) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(cards[i].$1, style: Theme.of(context).textTheme.bodySmall),
                  Text(cards[i].$2,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Frekuensi breakdown per ${gran == 'day' ? 'hari' : gran == 'week' ? 'minggu' : 'bulan'}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _FreqChart(st: st, gran: gran),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _Pareto(title: 'Top 10 Trouble', items: st.topTrouble),
        _Pareto(title: 'Top 10 Section', items: st.topSection),
        _Pareto(title: 'Top 10 Code', items: st.topCode),
        _Pareto(title: 'Top 10 Code Number', items: st.topCn),
      ],
    );
  }
}

class _FreqChart extends StatelessWidget {
  final PerfStats st;
  final String gran;
  const _FreqChart({required this.st, required this.gran});

  @override
  Widget build(BuildContext context) {
    final piv = pivotSeries(st.series);
    if (piv.periods.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Tidak ada data.')),
      );
    }
    final maxTotal = piv.totals.values.fold<int>(0, math.max);
    final interval = (piv.periods.length / 8).ceil().clamp(1, 1 << 30);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: BarChart(
            BarChartData(
              maxY: (maxTotal * 1.15).ceilToDouble().clamp(1, double.infinity),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, __) {
                    final p = piv.periods[group.x];
                    final row = piv.cells[p] ?? {};
                    final buf = StringBuffer('Total ${piv.totals[p] ?? 0}');
                    for (final b in piv.bars) {
                      buf.write('\n$b: ${row[b] ?? 0}');
                    }
                    return BarTooltipItem(
                      buf.toString(),
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: interval.toDouble(),
                    reservedSize: 56,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= piv.periods.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Transform.rotate(
                          angle: -0.6,
                          child: Text(
                            fmtPeriod(piv.periods[i], gran),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < piv.periods.length; i++)
                  _stackedGroup(
                    i,
                    piv.cells[piv.periods[i]] ?? {},
                    piv.bars,
                    scheme,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          children: [
            for (var b = 0; b < piv.bars.length; b++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    color: _chartColors[b % _chartColors.length],
                  ),
                  const SizedBox(width: 4),
                  Text(piv.bars[b], style: const TextStyle(fontSize: 12)),
                ],
              ),
          ],
        ),
      ],
    );
  }

  BarChartGroupData _stackedGroup(
    int x,
    Map<String, int> row,
    List<String> bars,
    ColorScheme scheme,
  ) {
    var cum = 0.0;
    final rods = <BarChartRodData>[];
    for (var b = 0; b < bars.length; b++) {
      final n = (row[bars[b]] ?? 0).toDouble();
      if (n <= 0) continue;
      final isTop = b == bars.length - 1 ||
          bars.sublist(b + 1).every((o) => (row[o] ?? 0) <= 0);
      rods.add(
        BarChartRodData(
          fromY: cum,
          toY: cum + n,
          width: 14,
          color: _chartColors[b % _chartColors.length],
          borderRadius: isTop
              ? const BorderRadius.vertical(top: Radius.circular(3))
              : BorderRadius.zero,
        ),
      );
      cum += n;
    }
    if (rods.isEmpty) {
      rods.add(BarChartRodData(fromY: 0, toY: 0, width: 14, color: scheme.surface));
    }
    return BarChartGroupData(x: x, barRods: rods);
  }
}

class _Pareto extends StatelessWidget {
  final String title;
  final List<TopItem> items;
  const _Pareto({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final maxV = items.fold<int>(0, (m, e) => math.max(m, e.v));
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('Tidak ada data.')
            else
              for (final d in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          d.k.length > 22 ? '${d.k.substring(0, 22)}…' : d.k,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxV > 0 ? d.v / maxV : 0,
                            minHeight: 14,
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 36,
                        child: Text('${d.v}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
