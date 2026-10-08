/// Model agregat Performance — kontrak dbr.py:136-202 + client.ts:202-211.
class StatsPoint {
  final String period; // YYYY-MM-DD (awal periode)
  final String prefix;
  final int n;
  const StatsPoint({required this.period, required this.prefix, required this.n});

  factory StatsPoint.fromJson(Map<String, dynamic> j) {
    var p = '${j['period'] ?? ''}';
    if (p.length >= 10) p = p.substring(0, 10);
    return StatsPoint(
      period: p,
      prefix: '${j['prefix'] ?? ''}',
      n: (j['n'] as num?)?.toInt() ?? 0,
    );
  }
}

class TopItem {
  final String k;
  final int v;
  const TopItem({required this.k, required this.v});

  factory TopItem.fromJson(Map<String, dynamic> j) =>
      TopItem(k: '${j['k'] ?? ''}', v: (j['v'] as num?)?.toInt() ?? 0);
}

class PerfSummary {
  final int total;
  final int units;
  final int days;
  final int emptyCode;
  const PerfSummary({this.total = 0, this.units = 0, this.days = 0, this.emptyCode = 0});

  factory PerfSummary.fromJson(Map<String, dynamic>? j) => PerfSummary(
        total: (j?['total'] as num?)?.toInt() ?? 0,
        units: (j?['units'] as num?)?.toInt() ?? 0,
        days: (j?['days'] as num?)?.toInt() ?? 0,
        emptyCode: (j?['empty_code'] as num?)?.toInt() ?? 0,
      );

  String get avgPerDay => days > 0 ? (total / days).toStringAsFixed(1) : '-';
}

class PerfStats {
  final String granularity;
  final bool excludeContinue;
  final int excludedContinue;
  final List<StatsPoint> series;
  final List<TopItem> topTrouble;
  final List<TopItem> topSection;
  final List<TopItem> topCode;
  final List<TopItem> topCn;
  final PerfSummary summary;

  const PerfStats({
    this.granularity = 'week',
    this.excludeContinue = true,
    this.excludedContinue = 0,
    this.series = const [],
    this.topTrouble = const [],
    this.topSection = const [],
    this.topCode = const [],
    this.topCn = const [],
    this.summary = const PerfSummary(),
  });

  factory PerfStats.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List? ?? []).map((e) => f((e as Map).cast<String, dynamic>())).toList());
    return PerfStats(
      granularity: '${j['granularity'] ?? 'week'}',
      excludeContinue: j['exclude_continue'] == true,
      excludedContinue: (j['excluded_continue'] as num?)?.toInt() ?? 0,
      series: list('series', StatsPoint.fromJson),
      topTrouble: list('top_trouble', TopItem.fromJson),
      topSection: list('top_section', TopItem.fromJson),
      topCode: list('top_code', TopItem.fromJson),
      topCn: list('top_cn', TopItem.fromJson),
      summary: PerfSummary.fromJson((j['summary'] as Map?)?.cast<String, dynamic>()),
    );
  }
}

/// Pivot series -> periode urut + top 6 prefix + Lainnya (Performance.tsx:46-64).
class Pivoted {
  final List<String> periods;
  final List<String> bars; // top prefix + (Lainnya?)
  final Map<String, Map<String, int>> cells; // period -> {prefix: n}
  final Map<String, int> totals; // period -> total
  const Pivoted(this.periods, this.bars, this.cells, this.totals);
}

Pivoted pivotSeries(List<StatsPoint> series) {
  final pfxTotals = <String, int>{};
  for (final s in series) {
    pfxTotals[s.prefix] = (pfxTotals[s.prefix] ?? 0) + s.n;
  }
  final top = (pfxTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .take(6)
      .map((e) => e.key)
      .toList();
  final periods = <String>[];
  for (final s in series) {
    if (!periods.contains(s.period)) periods.add(s.period);
  }
  periods.sort();
  final cells = <String, Map<String, int>>{};
  final totals = <String, int>{};
  var hasOther = false;
  for (final p in periods) {
    final row = <String, int>{};
    var other = 0;
    var total = 0;
    for (final s in series) {
      if (s.period != p) continue;
      total += s.n;
      if (top.contains(s.prefix)) {
        row[s.prefix] = (row[s.prefix] ?? 0) + s.n;
      } else {
        other += s.n;
      }
    }
    if (other > 0) {
      row['Lainnya'] = other;
      hasOther = true;
    }
    cells[p] = row;
    totals[p] = total;
  }
  return Pivoted(periods, [...top, if (hasOther) 'Lainnya'], cells, totals);
}
