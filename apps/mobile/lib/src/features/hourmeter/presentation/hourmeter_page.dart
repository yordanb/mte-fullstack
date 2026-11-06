import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/network/dio_client.dart' show apiMessage;
import '../../../core/widgets/app_scaffold.dart';
import '../data/hourmeter_api.dart';
import '../domain/hourmeter_models.dart';
import 'hourmeter_providers.dart';

/// Angka gaya Indonesia: pemisah ribuan titik (web toLocaleString).
String hmNum(int? v) =>
    v == null ? '·' : v.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');

/// Hourmeter — grid HM bulanan per unit (PUMPING), sumber upload Excel.
/// Paritas web Hourmeter.tsx: pilih Bulan/Tahun + Upload Excel + statistik.
class HourmeterPage extends ConsumerStatefulWidget {
  const HourmeterPage({super.key});

  @override
  ConsumerState<HourmeterPage> createState() => _HourmeterPageState();
}

class _HourmeterPageState extends ConsumerState<HourmeterPage> {
  bool _uploading = false;
  String _msg = '';
  bool _msgErr = false;

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(hourmeterPeriodProvider);
    final pivotAsync = ref.watch(hourmeterPivotProvider);
    final statsAsync = ref.watch(hourmeterStatsProvider);
    final auth = ref.watch(authProvider);
    // Web: admin ATAU izin hourmeter/add.
    final canUpload = auth.isAdmin || auth.can('hourmeter', 'add');

    final curPeriod = statsAsync.maybeWhen(
      data: (s) => s.periods
          .where((p) => p.period == period.key)
          .cast<HourmeterPeriod?>()
          .firstWhere((_) => true, orElse: () => null),
      orElse: () => null,
    );
    final lastLog = statsAsync.maybeWhen(
      data: (s) => s.logs.isEmpty ? null : s.logs.first,
      orElse: () => null,
    );

    return AppScaffold(
      title: 'Hourmeter',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(hourmeterPivotProvider);
          ref.invalidate(hourmeterStatsProvider);
          await ref.read(hourmeterPivotProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _toolbar(period, canUpload),
            const SizedBox(height: 8),
            _statsLine(period, curPeriod, lastLog, canUpload),
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
                  ? _empty('Belum ada data ${hourmeterMonths[period.month - 1]} '
                      '${period.year}. '
                      '${canUpload ? 'Klik "Upload Excel HM" dengan file seperti '
                          '"hm pumping okt 26.xlsx".' : 'Hubungi admin untuk upload data.'}')
                  : _grid(p),
            ),
            const SizedBox(height: 8),
            Text(
              'Sumber: upload Excel manual (sheet HM_Manual). Sel kosong berarti '
              'tidak ada pembacaan HM hari itu. Akhir = pembacaan HM terakhir hari '
              'itu bulan; Selisih = Akhir − Opening (dipakai HM bulan tersebut). '
              'Upload mengganti seluruh data periode yang dipilih.',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(HourmeterPeriodSel period, bool canUpload) {
    final notifier = ref.read(hourmeterPeriodProvider.notifier);
    final now = DateTime.now();
    final years = [now.year - 2, now.year - 1, now.year, now.year + 1, now.year + 2];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _dropdown(
              label: 'Bulan',
              value: period.month,
              items: [for (var m = 1; m <= 12; m++) (m, hourmeterMonths[m - 1])],
              onChanged: notifier.setMonth,
            ),
            _dropdown(
              label: 'Tahun',
              value: period.year,
              items: [for (final y in years) (y, '$y')],
              onChanged: notifier.setYear,
            ),
            if (canUpload)
              FilledButton.icon(
                onPressed: _uploading ? null : _pickAndUpload,
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(_uploading ? 'Mengupload…' : 'Upload Excel HM',
                    style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required int value,
    required List<(int, String)> items,
    required void Function(int) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
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

  Widget _statsLine(
    HourmeterPeriodSel period,
    HourmeterPeriod? cur,
    HourmeterLog? lastLog,
    bool canUpload,
  ) {
    final parts = <Widget>[];
    if (cur != null) {
      parts.add(_stat('Unit', '${cur.units}'));
      parts.add(_stat('Nilai HM', hmNum(cur.valuesCnt)));
      parts.add(Text('Upload mengganti seluruh data bulan ini',
          style: TextStyle(fontSize: 10.5, color: Colors.amber.shade800)));
    } else {
      parts.add(Text(
        'Belum ada data periode ini — '
        '${canUpload ? 'upload file Excel HM' : 'hubungi admin untuk upload'}.',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ));
    }
    if (lastLog != null) {
      final lp = lastLog.period.split('-');
      final label = lp.length == 2
          ? '${hourmeterMonths[(int.tryParse(lp[1]) ?? 1) - 1]} ${lp[0]}'
          : lastLog.period;
      parts.add(_stat('Upload terakhir',
          '$label • ${lastLog.uploadedBy ?? '-'}'));
    }
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts,
    );
  }

  Widget _stat(String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _msgBox() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _msgErr ? Colors.red.shade50 : Colors.blue.shade50,
          border: Border.all(
              color: _msgErr ? Colors.red.shade200 : Colors.blue.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(_msg,
            style: TextStyle(
                fontSize: 12,
                color: _msgErr ? Colors.red.shade700 : Colors.blue.shade700)),
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

  // ── Grid: baris = unit, kolom Opening + hari 1..31 + Akhir + Selisih ──
  Widget _grid(HourmeterPivot p) {
    final days = [for (var d = 1; d <= p.daysInMonth; d++) d];
    const cnW = 92.0, egiW = 110.0, numW = 58.0;

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
                    inside: BorderSide(color: Colors.grey.shade200, width: 0.5)),
                children: [
                  // Header hari di atas (pindah ke baris 2 kolom).
                  TableRow(decoration: BoxDecoration(color: Colors.grey.shade100),
                      children: [
                        _hCell('CN Unit', width: cnW, align: TextAlign.left),
                        _hCell('EGI', width: egiW, align: TextAlign.left),
                        _hCell('Opening', width: numW),
                        for (final d in days) _hCell('$d', width: 46),
                        _hCell('Akhir', width: numW),
                        _hCell('Selisih', width: numW),
                      ]),
                  for (var i = 0; i < p.units.length; i++)
                    _dataRow(p.units[i], days, i.isEven, cnW, egiW, numW),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TableRow _dataRow(
    HourmeterUnit u,
    List<int> days,
    bool even,
    double cnW,
    double egiW,
    double numW,
  ) {
    final bg = even ? Colors.white : Colors.grey.shade50;
    return TableRow(
      decoration: BoxDecoration(color: bg),
      children: [
        _dCell(u.cn,
            width: cnW,
            align: TextAlign.left,
            bold: true,
            color: Colors.grey.shade800),
        _dCell(u.egi?.isNotEmpty == true ? u.egi! : '·',
            width: egiW, align: TextAlign.left, color: Colors.grey.shade400),
        _dCell(hmNum(u.opening), width: numW, color: Colors.grey.shade600),
        for (final d in days)
          _dCell(
            hmNum(u.vals['$d']),
            width: 46,
            color: u.vals['$d'] == null ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        _dCell(hmNum(u.finalHm), width: numW, bold: true),
        _dCell(
          hmNum(u.delta),
          width: numW,
          color: (u.delta ?? 0) < 0
              ? Colors.red.shade600
              : u.delta != null
                  ? Colors.green.shade700
                  : Colors.grey.shade300,
        ),
      ],
    );
  }

  Widget _hCell(String text,
      {required double width, TextAlign align = TextAlign.center}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
      alignment: align == TextAlign.center
          ? Alignment.center
          : Alignment.centerLeft,
      child: Text(text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _dCell(String text,
      {required double width,
      TextAlign align = TextAlign.center,
      Color? color,
      bool bold = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      alignment: align == TextAlign.center
          ? Alignment.center
          : Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal),
      ),
    );
  }

  Future<void> _pickAndUpload() async {
    final period = ref.read(hourmeterPeriodProvider);
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xlsm', 'xls'],
      withData: false,
    );
    final f = res?.files.single;
    if (f == null || f.path == null) return;
    setState(() {
      _uploading = true;
      _msg = 'Mengupload & membaca file...';
      _msgErr = false;
    });
    try {
      final r = await ref.read(hourmeterApiProvider).upload(
            path: f.path!,
            filename: f.name,
            year: period.year,
            month: period.month,
          );
      final lp = r.period.split('-');
      final label = lp.length == 2
          ? '${hourmeterMonths[(int.tryParse(lp[1]) ?? 1) - 1]} ${lp[0]}'
          : r.period;
      if (!mounted) return;
      setState(() {
        _msg = 'Upload OK: $label — ${r.units} unit, ${r.values} nilai HM '
            '(periode lama pada $label sudah diganti)';
        _msgErr = false;
      });
      ref.invalidate(hourmeterPivotProvider);
      ref.invalidate(hourmeterStatsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msg = 'Upload gagal: ${apiMessage(e)}';
        _msgErr = true;
      });
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}
