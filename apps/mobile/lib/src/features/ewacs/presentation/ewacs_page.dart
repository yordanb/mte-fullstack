import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/network/dio_client.dart' show apiMessage;
import '../../../core/widgets/app_scaffold.dart';
import '../data/ewacs_api.dart';
import '../domain/ewacs_models.dart';
import 'ewacs_providers.dart';

/// Ewacs Performance — KPI Physical Availability + ratio SCM/USM.
/// Paritas web Ewacs.tsx: filter tanggal/EGI/Crew/Unit/Kode + kartu KPI +
/// tren + tabel detail. Grafik web (Apex) diganti visual ringkas Flutter.
class EwacsPage extends ConsumerStatefulWidget {
  const EwacsPage({super.key});

  @override
  ConsumerState<EwacsPage> createState() => _EwacsPageState();
}

class _EwacsPageState extends ConsumerState<EwacsPage> {
  final _startCtl = TextEditingController();
  final _endCtl = TextEditingController();
  bool _init = false;
  String _msg = '';
  bool _importing = false;

  @override
  void dispose() {
    _startCtl.dispose();
    _endCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(ewacsFilterProvider);
    final filtersAsync = ref.watch(ewacsFiltersProvider);
    final kpiAsync = ref.watch(ewacsKpiProvider);
    final trendAsync = ref.watch(ewacsTrendProvider);
    final detailAsync = ref.watch(ewacsDetailProvider);
    final isAdmin = ref.watch(authProvider).isAdmin;

    if (!_init) {
      _startCtl.text = f.start;
      _endCtl.text = f.end;
      _init = true;
    }

    return AppScaffold(
      title: 'Ewacs Performance',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ewacsKpiProvider);
          ref.invalidate(ewacsTrendProvider);
          ref.invalidate(ewacsDetailProvider);
          await ref.read(ewacsKpiProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _filterCard(f,
                filtersAsync.maybeWhen(data: (v) => v, orElse: () => null),
                isAdmin),
            if (_msg.isNotEmpty) ...[const SizedBox(height: 8), _msgBox()],
            const SizedBox(height: 10),
            kpiAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => _err(apiMessage(e)),
              data: (k) => _kpiCards(k),
            ),
            const SizedBox(height: 10),
            trendAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => _err(apiMessage(e)),
              data: (t) => t.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        _paChart(t),
                        const SizedBox(height: 10),
                        _breakdownChart(t),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            detailAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _err(apiMessage(e)),
              data: (d) => d.isEmpty
                  ? _empty(isAdmin)
                  : _detailTable(d),
            ),
            const SizedBox(height: 8),
            Text(
              'Physical Availability = (24 × unit × hari − durasi SCM+USM) / '
              '(24 × unit × hari) × 100%. Ratio SCM vs USM = persentase durasi '
              'breakdown scheduled vs unscheduled.',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterCard(EwacsFilter f, EwacsFilters? filters, bool isAdmin) {
    final notifier = ref.read(ewacsFilterProvider.notifier);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _dateField('Dari', _startCtl, () => _pickDate(_startCtl)),
            _dateField('Sampai', _endCtl, () => _pickDate(_endCtl)),
            _dropdown('EGI', f.egi, filters?.egi ?? const [],
                (v) => notifier.apply(egi: v)),
            _dropdown('Crew', f.crew, filters?.crew ?? const [],
                (v) => notifier.apply(crew: v)),
            _dropdown('Unit', f.cn, filters?.cn ?? const [],
                (v) => notifier.apply(cn: v)),
            _dropdown('Kode', f.kode, ewacsKodes,
                (v) => notifier.apply(kode: v)),
            FilledButton(
              onPressed: () => notifier.apply(
                  start: _startCtl.text.trim(), end: _endCtl.text.trim()),
              child: const Text('Tampilkan', style: TextStyle(fontSize: 12)),
            ),
            if (isAdmin)
              OutlinedButton.icon(
                onPressed: _importing ? null : _importCsv,
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(_importing ? 'Importing…' : 'Import CSV',
                    style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, TextEditingController ctl, VoidCallback onTap) =>
      SizedBox(
        width: 130,
        child: InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              border: const OutlineInputBorder(),
              labelStyle: const TextStyle(fontSize: 11),
            ),
            child: Text(ctl.text, style: const TextStyle(fontSize: 12)),
          ),
        ),
      );

  Widget _dropdown(String label, String value, List<String> items,
      void Function(String) onChanged) {
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
          child: DropdownButton<String>(
            value: value.isEmpty ? '' : value,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontSize: 12, color: Colors.black),
            items: [
              const DropdownMenuItem(value: '', child: Text('Semua')),
              for (final it in items) DropdownMenuItem(value: it, child: Text(it)),
            ],
            onChanged: (v) => onChanged(v ?? ''),
          ),
        ),
      ],
    );
  }

  Widget _kpiCards(EwacsKpi k) {
    Widget card(String label, String value, String sub, Color color) => Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              Text(sub,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ],
          ),
        );
    final paColor = k.pa >= 80
        ? Colors.green.shade600
        : k.pa >= 60
            ? Colors.orange.shade600
            : Colors.red.shade600;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          card('Physical Availability', '${k.pa.toStringAsFixed(2)}%',
              'Target ≥ 80%', paColor),
          const SizedBox(width: 8),
          card('SCM (Scheduled)', '${k.scmDur.toStringAsFixed(0)} j',
              '${k.scmPct.toStringAsFixed(1)}% dari total', Colors.blue.shade600),
          const SizedBox(width: 8),
          card('USM (Unscheduled)', '${k.usmDur.toStringAsFixed(0)} j',
              '${k.usmPct.toStringAsFixed(1)}% dari total', Colors.orange.shade600),
          const SizedBox(width: 8),
          card('Total Downtime', '${k.totalDowntime.toStringAsFixed(0)} j',
              'SCM + USM', Colors.grey.shade700),
          const SizedBox(width: 8),
          card('Unit / Hari', '${k.unitCount} / ${k.dayCount}', 'Distinct count',
              Colors.grey.shade700),
        ],
      ),
    );
  }

  /// Tren PA % — garis ringkas dengan penanda batas 80% (web line chart).
  Widget _paChart(List<EwacsTrend> t) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tren Physical Availability (%)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: CustomPaint(
                painter: _PaPainter(t),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Breakdown duration per tanggal — batang harian SCM & USM.
  Widget _breakdownChart(List<EwacsTrend> t) {
    final maxV = t.fold<double>(
        1, (m, e) => [m, e.scmDur, e.usmDur].reduce((a, b) => a > b ? a : b));
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Breakdown Duration per Tanggal (jam)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(children: [
              _dot(Colors.blue.shade600, 'SCM'),
              const SizedBox(width: 12),
              _dot(Colors.orange.shade600, 'USM'),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: t.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final e = t[i];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _bar(e.scmDur / maxV, Colors.blue.shade500),
                          const SizedBox(width: 2),
                          _bar(e.usmDur / maxV, Colors.orange.shade500),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 44,
                        child: Text(
                          e.tanggal.length >= 10
                              ? e.tanggal.substring(5, 10)
                              : e.tanggal,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 8.5),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(double frac, Color color) => Container(
        width: 8,
        height: (frac.clamp(0, 1)) * 80 + 2,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2)),
      );

  Widget _dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ]);

  Widget _detailTable(List<EwacsDetail> rows) {
    const hdrs = [
      'Tanggal', 'Unit', 'EGI', 'Kode', 'Durasi', 'Shift', 'Crew',
      'Start BD', 'RFU', 'Trouble', 'Mekanik', 'Action',
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
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
                      for (final h in hdrs)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 7, horizontal: 8),
                          child: Text(h,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  for (var i = 0; i < rows.length; i++) _detailRow(rows[i], i.isEven),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TableRow _detailRow(EwacsDetail r, bool even) {
    Widget c(String v, {Color? color, bool bold = false, double width = 0}) =>
        Container(
          width: width == 0 ? null : width,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
        );
    return TableRow(
      decoration: BoxDecoration(color: even ? Colors.white : Colors.grey.shade50),
      children: [
        c(r.tanggal),
        c(r.cn, bold: true),
        c(r.egi ?? '-'),
        c(r.kode,
            color: r.kode == 'SCM'
                ? Colors.blue.shade600
                : r.kode == 'USM'
                    ? Colors.orange.shade600
                    : null,
            bold: true),
        c('${r.durasi.toStringAsFixed(2)} j'),
        c(r.shift ?? '-'),
        c(r.crew ?? '-'),
        c(r.startBd ?? '-'),
        c(r.rfu ?? '-'),
        c(r.troubleDesc ?? '-', width: 200),
        c(r.mekanik ?? '-'),
        c(r.action ?? '-', width: 250),
      ],
    );
  }

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

  Widget _err(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('Gagal memuat: $text',
            style: TextStyle(fontSize: 12, color: Colors.red.shade600)),
      );

  Widget _empty(bool isAdmin) => Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Belum ada data. ${isAdmin ? 'Klik "Import CSV" untuk upload file breakdown.' : 'Hubungi admin untuk import data.'}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );

  Future<void> _pickDate(TextEditingController ctl) async {
    final init = DateTime.tryParse(ctl.text) ?? DateTime.now();
    final p = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (p == null) return;
    final iso =
        '${p.year}-${p.month.toString().padLeft(2, '0')}-${p.day.toString().padLeft(2, '0')}';
    setState(() => ctl.text = iso);
    ref.read(ewacsFilterProvider.notifier).apply(start: _startCtl.text, end: _endCtl.text);
  }

  Future<void> _importCsv() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: false,
    );
    final f = res?.files.single;
    if (f == null || f.path == null) return;
    setState(() {
      _importing = true;
      _msg = 'importing...';
    });
    try {
      final r = await ref
          .read(ewacsApiProvider)
          .importCsv(path: f.path!, filename: f.name);
      if (!mounted) return;
      setState(() => _msg =
          'import OK: ${r.inserted} baru, ${r.updated} diperbarui'
          '${r.deleted > 0 ? ', ${r.deleted} dibuang (tidak ada di file)' : ''}'
          '${r.duplicates > 0 ? ', ${r.duplicates} duplikat di file' : ''}'
          '${r.skipped > 0 ? ', ${r.skipped} skip' : ''}'
          ' — total ${r.totalRows} baris');
      ref.invalidate(ewacsKpiProvider);
      ref.invalidate(ewacsTrendProvider);
      ref.invalidate(ewacsDetailProvider);
      ref.invalidate(ewacsFiltersProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _msg = 'import gagal: ${apiMessage(e)}');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }
}

/// Pelukis garis tren PA % dengan batas target 80% merah putus-putus.
class _PaPainter extends CustomPainter {
  final List<EwacsTrend> data;
  _PaPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final grid = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    final line = Paint()
      ..color = Colors.green.shade600
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final target = Paint()
      ..color = Colors.red.shade400
      ..strokeWidth = 1;

    // Batas 80% target.
    final y80 = size.height * (1 - 0.8);
    canvas.drawLine(Offset(0, y80), Offset(size.width, y80), target);

    final pts = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = data.length == 1
          ? size.width / 2
          : i / (data.length - 1) * size.width;
      final y = size.height * (1 - (data[i].pa.clamp(0, 100) / 100));
      pts.add(Offset(x, y));
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = Colors.green.shade600;
    for (final p in pts) {
      canvas.drawCircle(p, 2, dot);
    }
    // Sumbu bawah.
    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), grid);
  }

  @override
  bool shouldRepaint(covariant _PaPainter old) => old.data != data;
}
