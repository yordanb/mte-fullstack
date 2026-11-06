import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/manpower_models.dart';

final NumberFormat _nfmt = NumberFormat.decimalPattern('id-ID');
final NumberFormat _pctfmt =
    NumberFormat.decimalPatternDigits(locale: 'id-ID', decimalDigits: 1);

/// Angka bulat gaya web fmtNum.
String mpNum(num? v) {
  if (v == null) return '-';
  return _nfmt.format(v.round());
}

/// Persentase 1 desimal gaya web fmtPct.
String mpPct(num? v) {
  if (v == null) return '-';
  return '${_pctfmt.format(v)}%';
}

/// Rasio 2 desimal gaya web fmtRatio.
String mpRatio(num? v) {
  if (v == null) return '-';
  final f = NumberFormat.decimalPatternDigits(locale: 'id-ID', decimalDigits: 2);
  return f.format(v);
}

/// Kartu ringkasan dashboard (judul, nilai, subteks, warna nilai).
class ManpowerStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? suffix;
  final String subtitle;
  final Color valueColor;
  final Widget? extra;

  const ManpowerStatCard({
    super.key,
    required this.title,
    required this.value,
    this.suffix,
    this.subtitle = '',
    this.valueColor = const Color(0xFF2563EB),
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: valueColor),
                children: [
                  TextSpan(text: value),
                  if (suffix != null)
                    TextSpan(
                      text: ' $suffix',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
            if (extra != null) ...[const SizedBox(height: 4), extra!],
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bar persentase kecil (untuk coverage).
class ManpowerBar extends StatelessWidget {
  final double pct;
  final Color color;
  const ManpowerBar({super.key, required this.pct, this.color = Colors.green});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: (pct.clamp(0, 100)) / 100,
        minHeight: 6,
        backgroundColor: Colors.grey.shade200,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

/// Grafik batang sederhana Manpower vs Innovator SS per bulan
/// (pengganti ApexCharts web).
class ManpowerTrendChart extends StatelessWidget {
  final List<ManpowerPeriod> trend;
  const ManpowerTrendChart({super.key, required this.trend});

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text('Belum ada data tren.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      );
    }
    final maxManpower = trend
        .map((t) => t.manpower)
        .fold<int>(1, (a, b) => b > a ? b : a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legend(Colors.blue, 'Manpower'),
            const SizedBox(width: 12),
            _legend(Colors.green, 'Innovator SS'),
          ],
        ),
        const SizedBox(height: 8),
        for (final t in trend)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(manpowerFmtPeriode(t.periode),
                    style: TextStyle(
                        fontSize: 10.5, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                _bar(mpNum(t.manpower), t.manpower, maxManpower, Colors.blue),
                const SizedBox(height: 2),
                _bar(mpNum(t.innovatorSs), t.innovatorSs, maxManpower,
                    Colors.green),
              ],
            ),
          ),
      ],
    );
  }

  Widget _legend(Color c, String label) => Row(
        children: [
          Container(width: 10, height: 10, color: c),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10.5)),
        ],
      );

  Widget _bar(String label, int value, int max, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(label,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 10)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (c, box) => Row(
              children: [
                Container(
                  width: max == 0 ? 0 : (value / max) * box.maxWidth,
                  height: 9,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(2)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
