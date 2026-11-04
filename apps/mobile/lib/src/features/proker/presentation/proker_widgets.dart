import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_fmt.dart' show fmtDate;
import '../domain/proker_models.dart';

// ── Format angka & tanggal ala web (fmtNum/fmtHm/fmtSigned/fmtDate) ────────

final NumberFormat _nfmt = NumberFormat.decimalPattern('id_ID');
final NumberFormat _hmfmt = NumberFormat.decimalPattern('id_ID')
  ..maximumFractionDigits = 2;

/// Angka ribuan dibulatkan (web fmtNum Math.round).
String fmtNum(num? v) => v == null ? '-' : _nfmt.format(v.round());

/// HM maksimal 2 desimal (web fmtHm).
String fmtHm(num? v) => v == null ? '-' : _hmfmt.format(v);

/// Nilai bertanda + / - (web fmtSigned).
String fmtSigned(num? v) {
  if (v == null) return '-';
  final n = v.toDouble();
  return '${n > 0 ? '+' : ''}${fmtHm(n)}';
}

/// Tanggal dd/MM/yyyy, '-' bila kosong (web fmtDate).
String fmtDateDash(String? v) =>
    (v == null || v.trim().isEmpty) ? '-' : fmtDate(v);

// ── Tingkat "jatuh tempo" (dipakai warna teks) ─────────────────────────────

enum DueLevel { none, ok, warn, bad }

/// Booster: sisa jam <= 0 -> lewat; Thermostat-pola sama.
DueLevel dueLevel(num? v) =>
    v == null ? DueLevel.none : (v <= 0 ? DueLevel.bad : DueLevel.ok);

/// Injector: umur >= interval merah, >= 80% interval kuning (web ageCls).
DueLevel injectorAgeLevel(num? age, num interval) {
  if (age == null) return DueLevel.none;
  final a = age.toDouble();
  final iv = interval.toDouble();
  if (iv <= 0) return a > 0 ? DueLevel.bad : DueLevel.ok;
  if (a >= iv) return DueLevel.bad;
  if (a >= iv * 0.8) return DueLevel.warn;
  return DueLevel.ok;
}

/// Thermostat: deviasi >= 0 (sudah lewat target) merah, selain itu hijau.
DueLevel thermoDeviasiLevel(num? v) =>
    v == null ? DueLevel.none : (v >= 0 ? DueLevel.bad : DueLevel.ok);

Color dueLevelColor(DueLevel l) => switch (l) {
      DueLevel.bad => const Color(0xFFD92D20),
      DueLevel.warn => const Color(0xFFDC6803),
      DueLevel.ok => const Color(0xFF039855),
      DueLevel.none => Colors.grey,
    };

// ── Selisih HM (Δ HM) ala web ──────────────────────────────────────────────

/// Proker: selisih HM terhadap eksekusi sebelumnya (urut kronologis:
/// tanggal, tahun, urutan, periode).
Map<int, double?> computeExecDeltas(List<ProkerExecution> execs) {
  final out = <int, double?>{};
  final asc = [...execs]..sort((a, b) {
      final da = a.serviceDate ?? '';
      final db = b.serviceDate ?? '';
      if (da != db) return da.compareTo(db);
      final y = (a.periodYear ?? 0).compareTo(b.periodYear ?? 0);
      if (y != 0) return y;
      final s = (a.periodSeq ?? 0).compareTo(b.periodSeq ?? 0);
      if (s != 0) return s;
      return a.period.compareTo(b.period);
    });
  double? prev;
  for (final e in asc) {
    final hm = e.hm;
    out[e.id] = (hm != null && prev != null) ? hm - prev : null;
    if (hm != null) prev = hm;
  }
  return out;
}

/// Booster: selisih HM terhadap event sebelumnya (urut HM naik).
Map<int, double?> computeEventDeltas(List<BoosterEvent> events) {
  final out = <int, double?>{};
  final asc = [...events]..sort((a, b) => a.hm.compareTo(b.hm));
  double? prev;
  for (final e in asc) {
    out[e.id] = prev == null ? null : e.hm - prev;
    prev = e.hm;
  }
  return out;
}

/// Grup penggantian injector per nomor penggantian (seq turun, posisi naik).
class InjectorReplGroup {
  final int seq;
  final List<InjectorReplacement> rows;
  const InjectorReplGroup({required this.seq, required this.rows});
}

List<InjectorReplGroup> groupReplacements(List<InjectorReplacement> reps) {
  final map = <int, List<InjectorReplacement>>{};
  for (final r in reps) {
    map.putIfAbsent(r.seq, () => []).add(r);
  }
  final seqs = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final s in seqs)
      InjectorReplGroup(
        seq: s,
        rows: [...map[s]!]..sort((a, b) => a.position.compareTo(b.position)),
      ),
  ];
}

/// Tingkat sel posisi injector (web posCls): PLAN khusus, sisanya per umur.
enum PosLevel { plan, empty, ok, warn, bad }

PosLevel posLevel(InjectorPosition p, num interval) {
  if (p.status == 'PLAN') return PosLevel.plan;
  if (p.hm == null) return PosLevel.empty;
  return switch (injectorAgeLevel(p.age, interval)) {
    DueLevel.bad => PosLevel.bad,
    DueLevel.warn => PosLevel.warn,
    _ => PosLevel.ok,
  };
}

// ── Badge & label status ───────────────────────────────────────────────────

const _greenBg = Color(0xFFD1FADF);
const _greenFg = Color(0xFF027A48);
const _amberBg = Color(0xFFFEF0C7);
const _amberFg = Color(0xFFB54708);
const _redBg = Color(0xFFFEE4E2);
const _redFg = Color(0xFFB42318);
const _grayBg = Color(0xFFEAECF0);
const _grayFg = Color(0xFF344054);
const _blueBg = Color(0xFFD1E9FF);
const _blueFg = Color(0xFF175CD3);
const _brandBg = Color(0xFFEFF4FF);
const _brandFg = Color(0xFF3538CD);

class PillBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final double fontSize;

  const PillBadge({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(
          label,
          style: TextStyle(
              fontSize: fontSize, fontWeight: FontWeight.w600, color: fg),
        ),
      );
}

/// Status eksekusi proker: DONE=Selesai, PLAN=Rencana, LATE=Terlambat,
/// MISSED=Terlewat (web Proker.tsx STATUS).
PillBadge prokerStatusBadge(String status) => switch (status.toUpperCase()) {
      'DONE' => const PillBadge(label: 'Selesai', bg: _greenBg, fg: _greenFg),
      'PLAN' => const PillBadge(label: 'Rencana', bg: _amberBg, fg: _amberFg),
      'LATE' => const PillBadge(label: 'Terlambat', bg: _redBg, fg: _redFg),
      'MISSED' => const PillBadge(label: 'Terlewat', bg: _grayBg, fg: _grayFg),
      _ => PillBadge(label: status, bg: _grayBg, fg: _grayFg),
    };

String boosterKindLabel(String? kind) => switch (kind) {
      'OVH' => 'OVH',
      'MIDLIFE' => 'Midlife',
      _ => '-',
    };

PillBadge boosterKindBadge(String? kind) => switch (kind) {
      'OVH' => const PillBadge(label: 'OVH', bg: _blueBg, fg: _blueFg),
      'MIDLIFE' => const PillBadge(label: 'Midlife', bg: _greenBg, fg: _greenFg),
      _ => const PillBadge(label: '-', bg: _grayBg, fg: _grayFg),
    };

/// Status penggantian injector: DONE=Terpasang, PLAN=Rencana.
PillBadge injectorStatusBadge(String status) => switch (status.toUpperCase()) {
      'DONE' => const PillBadge(label: 'Terpasang', bg: _greenBg, fg: _greenFg),
      'PLAN' => const PillBadge(label: 'Rencana', bg: _amberBg, fg: _amberFg),
      _ => PillBadge(label: status, bg: _grayBg, fg: _grayFg),
    };

/// Status modif 74°C thermostat: DONE hijau, selain itu NOT YET kuning.
PillBadge thermoModifBadge(String? status) {
  final s = (status ?? '').toUpperCase();
  return s == 'DONE'
      ? const PillBadge(label: 'DONE', bg: _greenBg, fg: _greenFg)
      : const PillBadge(label: 'NOT YET', bg: _amberBg, fg: _amberFg);
}

/// Badge "Midlife Eng CAT {model}" pada detail Proker pompa primer.
PillBadge midlifeEngineBadge(String? merk, String? model) {
  final m = (merk == null || merk.isEmpty) ? 'CAT' : merk;
  final mm = (model == null || model.isEmpty) ? '' : ' $model';
  return PillBadge(label: 'Midlife Eng $m$mm', bg: _brandBg, fg: _brandFg);
}

/// Badge catatan/remark unit (kuning) — dipakai detail booster.
PillBadge remarkBadge(String remark) =>
    PillBadge(label: remark, bg: _amberBg, fg: _amberFg, fontSize: 10);

/// Badge nomor penggantian injector "P{seq}".
PillBadge injectorSeqBadge(int seq) =>
    PillBadge(label: 'P$seq', bg: _brandBg, fg: _brandFg);

// ── Kartu & komponen umum ──────────────────────────────────────────────────

const Color prokerBrand = Color(0xFF465FFF);
const Color prokerGreen = Color(0xFF16A34A);
const Color prokerAmber = Color(0xFFD97706);
const Color prokerRed = Color(0xFFD92D20);
const Color prokerGray = Color(0xFF344054);
const Color prokerHeadGreen = Color(0xFF027A48);
const Color prokerHeadAmber = Color(0xFFB54708);

/// Kartu KPI: label kecil, angka besar berwarna, sub-teks.
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String sub;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 2),
              Text(sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
}

Widget prokerKpiGrid(List<Widget> cards) => GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: cards,
    );

/// Kartu seksi dengan judul + subjudul + aksi kanan.
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey, fontSize: 10.5)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// Kotak statistik detail unit (label, nilai, sub).
class StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final String sub;

  const StatBox({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: valueColor)),
          Text(sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

/// Baris info mini dengan titik warna (OVH/Midlife/last thermostat/modif).
class MiniInfo extends StatelessWidget {
  final Color dotColor;
  final String label;
  final String value;
  final String? sub;
  final Widget? badge;

  const MiniInfo({
    super.key,
    required this.dotColor,
    required this.label,
    required this.value,
    this.sub,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              Text(value,
                  style: const TextStyle(
                      fontSize: 11, fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 2),
              child: Text(sub!,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ),
          if (badge != null)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 4),
              child: badge!,
            ),
        ],
      ),
    );
  }
}

/// Kartu baris unit pada daftar (C/N + model + sub, kanan nilai ringkas).
class UnitTile extends StatelessWidget {
  final String cn;
  final String model;
  final String sub;
  final List<Widget> trailing;
  final VoidCallback onTap;

  const UnitTile({
    super.key,
    required this.cn,
    required this.model,
    required this.sub,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cn,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                      Text(model,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                      if (sub.isNotEmpty)
                        Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: trailing,
                ),
              ],
            ),
          ),
        ),
      );
}

/// Teks nilai utama pada trailing kartu unit.
Widget tileValue(String v, {Color? color}) => Text(v,
    style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.bold, color: color));

/// Teks kecil abu pada trailing kartu unit.
Widget tileNote(String v, {Color? color}) => Text(v,
    style: TextStyle(
        fontSize: 10,
        color: color ?? Colors.grey.shade500,
        fontFeatures: const [FontFeature.tabularFigures()]));

/// Dropdown filter gaya ringkas dengan opsi "Semua" ('').
class FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final double width;

  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 150,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
          DropdownButton<String>(
            isExpanded: true,
            value: items.contains(value) ? value : '',
            underline: const SizedBox.shrink(),
            style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color),
            items: [
              const DropdownMenuItem(value: '', child: Text('Semua')),
              for (final v in items)
                DropdownMenuItem(
                  value: v,
                  child: Text(v, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => onChanged(v ?? ''),
          ),
        ],
      ),
    );
  }
}

/// Header panel detail: C/N besar + subjudul + badge/extra opsional.
class DetailHead extends StatelessWidget {
  final String cn;
  final String subtitle;
  final Widget? badge;
  final Widget? extra;

  const DetailHead({
    super.key,
    required this.cn,
    required this.subtitle,
    this.badge,
    this.extra,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cn,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: prokerBrand)),
          Text(subtitle, style: const TextStyle(fontSize: 12)),
          if (badge != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: badge!),
          if (extra != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: extra!),
        ],
      );
}

/// Tabel DataTable ringkas konsisten dengan halaman lain (scroll horizontal).
Widget prokerTable({
  required List<DataColumn> columns,
  required List<DataRow> rows,
}) =>
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 14,
        horizontalMargin: 8,
        headingTextStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        dataTextStyle: const TextStyle(fontSize: 11),
        columns: columns,
        rows: rows,
      ),
    );

/// Bottom sheet detail unit (tinggi 92%, bisa digulir).
Future<void> showProkerSheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.92, child: child),
    );

void prokerSnack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
