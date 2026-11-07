import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';

import '../data/yazu_api.dart';
import '../domain/yazu_models.dart';
import 'yazu_providers.dart';

/// Daftar kategori Yazu Pumping (urutan = urutan tab).
const List<(String, String)> yazuPumpingKategori = [
  ('primer', 'Primer'),
  ('mhp', 'MHP'),
  ('booster', 'Booster'),
];

/// Halaman pivot Yazu Pumping P2H — 3 kategori (Primer/MHP/Booster) lewat tab.
/// Meniru web YazuPumping.tsx: filter bulan/tahun + Sync Manual + toggle Anomali
/// + grid HM dengan warna kenaikan HM harian. Satu tombol sync menarik semua tab.
class YazuPumpingPage extends ConsumerStatefulWidget {
  const YazuPumpingPage({super.key});

  @override
  ConsumerState<YazuPumpingPage> createState() => _YazuPumpingPageState();
}

class _YazuPumpingPageState extends ConsumerState<YazuPumpingPage> {
  bool _showAnomaly = false;
  String _msg = '';
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(yazuPumpingMonthProvider);
    final kategori = ref.watch(yazuPumpingKategoriProvider);
    final pivotAsync = ref.watch(yazuPumpingPivotProvider);
    final statsAsync = ref.watch(yazuPumpingStatsProvider);
    final canSync = ref.watch(authProvider).can('yazupumping', 'add');

    final pivot = pivotAsync.maybeWhen(data: (v) => v, orElse: () => null);
    final stats = statsAsync.maybeWhen(data: (v) => v, orElse: () => null);
    final deltas = pivot == null ? null : yazuComputeDeltas(pivot);
    final summary = deltas == null ? null : yazuAnomalySummary(deltas);

    final now = DateTime.now();
    final isCurrentMonth =
        period.year == now.year && period.month == now.month;
    final katLabel = yazuPumpingKategori
        .firstWhere((e) => e.$1 == kategori, orElse: () => (kategori, kategori))
        .$2;

    return AppScaffold(
      title: 'Yazu Pumping P2H',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(yazuPumpingPivotProvider);
          ref.invalidate(yazuPumpingStatsProvider);
          await ref.read(yazuPumpingPivotProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _tabs(kategori),
            const SizedBox(height: 10),
            _toolbar(period, canSync, stats),
            if (_showAnomaly && summary != null) _anomalyBar(summary),
            if (_msg.isNotEmpty) ...[
              const SizedBox(height: 8),
              _msgBox(),
            ],
            const SizedBox(height: 10),
            pivotAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _empty('Gagal memuat: ${apiMessage(e)}'),
              data: (p) => p.units.isEmpty
                  ? _empty('Belum ada data kategori $katLabel untuk '
                      '${yazuMonths[period.month - 1]} ${period.year}. '
                      '${canSync ? 'Klik "Sync Manual" untuk ambil data dari Google Sheets.' : 'Hubungi admin untuk sync data.'}')
                  : _grid(p, deltas!, isCurrentMonth, now.day),
            ),
            const SizedBox(height: 8),
            Text(
              'Sumber: Google Sheets checklist inspeksi unit pompa (tab Primer / MHP / Booster). '
              'Sel berisi HM terakhir pada tanggal tersebut. Kolom hari ini di-highlight, '
              'kolom hari Minggu ditandai warna merah muda sebagai pembeda hari.'
              '${_showAnomaly ? ' Mode anomali: warna = kenaikan HM rata-rata per hari. HM mundur (delta < 0) = background merah.' : ''}',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabs(String kategori) => Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            for (final (key, label) in yazuPumpingKategori)
              InkWell(
                onTap: () =>
                    ref.read(yazuPumpingKategoriProvider.notifier).set(key),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: key == kategori
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: key == kategori
                              ? Colors.blue.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 2,
                        width: 44,
                        color: key == kategori
                            ? Colors.blue.shade600
                            : Colors.transparent,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _toolbar(YazuMonth period, bool canSync, YazuStats? stats) {
    final notifier = ref.read(yazuPumpingMonthProvider.notifier);
    final now = DateTime.now();
    final years = [
      now.year - 2,
      now.year - 1,
      now.year,
      now.year + 1,
      now.year + 2
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _dropdown('Bulan', period.month,
                [for (var m = 1; m <= 12; m++) (m, yazuMonths[m - 1])],
                notifier.setMonth),
            _dropdown('Tahun', period.year, [for (final y in years) (y, '$y')],
                notifier.setYear),
            if (canSync)
              FilledButton(
                onPressed: _syncing ? null : _doSync,
                child: Text(_syncing ? 'Syncing…' : 'Sync Manual',
                    style: const TextStyle(fontSize: 12)),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _showAnomaly,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => setState(() => _showAnomaly = v ?? false),
                ),
                const Text('Anomali', style: TextStyle(fontSize: 12)),
              ],
            ),
            if (stats != null) ...[
              _stat('Baris', _num(stats.totalRows)),
              _stat('Unit', '${stats.totalUnits}'),
              _stat('Akhir',
                  stats.lastDataWaktu == null ? '-' : _dtId(stats.lastDataWaktu)),
              if (stats.lastSync != null)
                _stat(
                    'Sync',
                    '${stats.lastSync!.finishedAt == null ? '-' : _dtId(stats.lastSync!.finishedAt)} '
                    '(${stats.lastSync!.status})'
                    '${stats.lastSync!.rowsUpserted != null ? ' → ${stats.lastSync!.rowsUpserted}/${stats.lastSync!.rowsTotal}' : ''}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _anomalyBar(YazuAnomalySummary s) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Analisa Anomali:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            _legendBg('■ HM mundur (delta < 0)', Colors.red.shade600),
            _legendDot('● > 24 jam (anomali)', Colors.red.shade600, bold: true),
            _legendDot('● 14–24 jam (di atas normal)', Colors.orange.shade600),
            _legendDot('● 10–14 jam (normal)', Colors.green.shade600),
            _legendDot('● < 10 jam (di bawah normal)', Colors.grey),
            _legendBg('Mundur: ${s.mundur}', Colors.red.shade600),
            _legendDot('Merah: ${s.merah}', Colors.red.shade600),
            _legendDot('Orange: ${s.orange}', Colors.orange.shade600),
            _legendDot('Hijau: ${s.hijau}', Colors.green.shade600),
            _legendDot('Lain: ${s.biasa}', Colors.grey),
          ],
        ),
      );

  Widget _legendBg(String text, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        color: bg,
        child: Text(text,
            style: const TextStyle(
                fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold)),
      );

  Widget _legendDot(String text, Color color, {bool bold = false}) => Text(text,
      style: TextStyle(
          fontSize: 10.5,
          color: color,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal));

  Widget _stat(String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _msgBox() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          border: Border.all(color: Colors.blue.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(_msg,
            style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
      );

  Widget _empty(String text) => Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      );

  Widget _dropdown(String label, int value, List<(int, String)> items,
      void Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<int>(
            value: value,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontSize: 12, color: Colors.black),
            items: [
              for (final it in items)
                DropdownMenuItem(value: it.$1, child: Text(it.$2)),
            ],
            onChanged: (v) => v == null ? null : onChanged(v),
          ),
        ),
      ],
    );
  }

  // ── Grid: baris = unit, kolom = hari 1..akhir bulan ──
  Widget _grid(YazuPivot p, Map<String, Map<int, double>> deltas,
      bool isCurrentMonth, int todayDay) {
    const unitW = 92.0, dayW = 46.0;
    final days = [for (var d = 1; d <= p.daysInMonth; d++) d];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 560),
            child: SingleChildScrollView(
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: TableBorder.symmetric(
                    inside:
                        BorderSide(color: Colors.grey.shade200, width: 0.5)),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: [
                      _headCell('ID Unit', width: unitW, align: TextAlign.left),
                      for (final d in days)
                        _dayHead(p, d, isCurrentMonth, todayDay),
                    ],
                  ),
                  for (var i = 0; i < p.units.length; i++)
                    _unitRow(p, deltas, p.units[i], days, i.isEven, unitW, dayW,
                        isCurrentMonth, todayDay),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayHead(YazuPivot p, int d, bool isCurrentMonth, int todayDay) {
    final isToday = isCurrentMonth && d == todayDay;
    final isSun = DateTime(p.year, p.month, d).weekday == DateTime.sunday;
    Color bg = Colors.grey.shade100;
    Color fg = Colors.black87;
    if (isToday) {
      bg = Colors.blue.shade100;
      fg = Colors.blue.shade800;
    } else if (isSun) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade400;
    }
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg),
      child: Text('$d',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  TableRow _unitRow(
    YazuPivot p,
    Map<String, Map<int, double>> deltas,
    String uid,
    List<int> days,
    bool even,
    double unitW,
    double dayW,
    bool isCurrentMonth,
    int todayDay,
  ) {
    final bg = even ? Colors.white : Colors.grey.shade50;
    final dm = p.cells[uid] ?? const <int, int?>{};
    final ud = deltas[uid] ?? const <int, double>{};
    return TableRow(
      decoration: BoxDecoration(color: bg),
      children: [
        Container(
          width: unitW,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          alignment: Alignment.centerLeft,
          child: Text(uid,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ),
        for (final d in days)
          _dayCell(p, dm[d], _showAnomaly ? ud[d] : null, d, isCurrentMonth,
              todayDay, dayW),
      ],
    );
  }

  Widget _dayCell(
    YazuPivot p,
    int? hm,
    double? delta,
    int d,
    bool isCurrentMonth,
    int todayDay,
    double width,
  ) {
    final isToday = isCurrentMonth && d == todayDay;
    final isSun = DateTime(p.year, p.month, d).weekday == DateTime.sunday;
    final level = _showAnomaly ? yazuDeltaLevel(delta) : YazuDeltaLevel.none;

    Color? bg;
    Color fg = Colors.grey.shade700;
    FontWeight fw = FontWeight.normal;

    switch (level) {
      case YazuDeltaLevel.mundur:
        bg = Colors.red.shade600;
        fg = Colors.white;
        fw = FontWeight.bold;
      case YazuDeltaLevel.merah:
        fg = Colors.red.shade600;
        fw = FontWeight.bold;
      case YazuDeltaLevel.orange:
        fg = Colors.orange.shade700;
        fw = FontWeight.w600;
      case YazuDeltaLevel.hijau:
        fg = Colors.green.shade600;
      case YazuDeltaLevel.biasa:
      case YazuDeltaLevel.none:
        if (hm == null) fg = Colors.grey.shade300;
    }
    if (isToday && bg == null) bg = Colors.blue.shade50;
    if (isSun && bg == null) bg = Colors.red.shade50.withValues(alpha: 0.5);

    final cell = Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      decoration: bg == null ? null : BoxDecoration(color: bg),
      child: Text(hm == null ? '·' : _num(hm),
          style: TextStyle(fontSize: 11, color: fg, fontWeight: fw)),
    );
    if (_showAnomaly && delta != null) {
      return Tooltip(message: yazuDeltaTitle(delta), child: cell);
    }
    return cell;
  }

  Widget _headCell(String text,
          {required double width, TextAlign align = TextAlign.center}) =>
      Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        alignment:
            align == TextAlign.center ? Alignment.center : Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Future<void> _doSync() async {
    setState(() {
      _syncing = true;
      _msg = 'syncing...';
    });
    try {
      final api = ref.read(yazuPumpingApiProvider);
      final r = await api.sync();
      if (!mounted) return;
      setState(() => _msg =
          'sync OK: ${r.rowsUpserted} rows dari ${r.rowsTotal} total');
      ref.invalidate(yazuPumpingPivotProvider);
      ref.invalidate(yazuPumpingStatsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _msg = 'sync gagal: ${apiMessage(e)}');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }
}

/// "12/11/2026 14:30" gaya id-ID (web toLocaleString('id-ID')).
String _dtId(String? v) {
  if (v == null) return '-';
  final d = DateTime.tryParse(v)?.toLocal();
  if (d == null) return v;
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${p2(d.day)}/${p2(d.month)}/${d.year} ${p2(d.hour)}:${p2(d.minute)}';
}

/// Format ribuan titik (web toLocaleString).
String _num(int n) =>
    n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
