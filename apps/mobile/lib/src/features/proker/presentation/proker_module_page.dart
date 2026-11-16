// Halaman generik untuk 8 modul proker baru yang shape endpoint-nya seragam
// (stats/filters/units/units/{cn}/refresh-hm): 2 exhaust, fandrebb, fanpompa,
// gmc, fire suppression booster/primer, ponton — paritas web Proker*.tsx.
// Scope mobile mengikuti halaman proker lama: tampilan + Refresh HM
// (tanpa form edit/import — itu tetap lewat web).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../data/proker_api.dart';
import '../domain/proker_models.dart';
import 'proker_providers.dart';
import 'proker_widgets.dart';

/// Konfigurasi tampilan satu modul proker baru.
class ProkerModuleSpec {
  final String id;
  final String title;
  final String introLead;
  final String introBold;
  final String introTail;
  final String listTitle;
  final String unitDoneSub;
  final String emptyHint;
  final bool showPontonFilter;
  final bool showDelta;
  final bool showWorkType;
  final bool planKpi;

  const ProkerModuleSpec({
    required this.id,
    required this.title,
    required this.introLead,
    required this.introBold,
    required this.introTail,
    required this.listTitle,
    required this.unitDoneSub,
    required this.emptyHint,
    this.showPontonFilter = false,
    this.showDelta = false,
    this.showWorkType = false,
    this.planKpi = false,
  });
}

const kExhaustSpec = ProkerModuleSpec(
  id: 'prokerexhaust',
  title: 'Proker Gen Repair Exhaust',
  introLead: 'Program kerja ',
  introBold: 'General Repair Exhaust Primer',
  introTail: ' — riwayat repair per periode per unit, data dari file Excel.',
  listTitle: 'Daftar Unit',
  unitDoneSub: 'unit sudah pernah proker',
  emptyHint: 'Belum ada unit. Import file exhaust (.xlsx) lewat web.',
  showDelta: true,
  showWorkType: true,
  planKpi: true,
);

const kExhaustMitsSpec = ProkerModuleSpec(
  id: 'prokerexhaustmits',
  title: 'Proker Exhaust Mitsura',
  introLead: 'Program kerja ',
  introBold: 'General Repair Exhaust Primer Mitsura',
  introTail: ' — riwayat repair per periode per unit, data dari file Excel.',
  listTitle: 'Daftar Unit',
  unitDoneSub: 'unit sudah pernah proker',
  emptyHint: 'Belum ada unit. Import file exhaust Mitsura (.xlsx) lewat web.',
  showDelta: true,
  showWorkType: true,
  planKpi: true,
);

const kFanDriveRebbSpec = ProkerModuleSpec(
  id: 'prokerfandrebb',
  title: 'Proker Rebearing Fan Drive',
  introLead: 'Program kerja ',
  introBold: 'Rebearing Fan Drive Primer',
  introTail: ' — riwayat penggantian bearing fan drive per unit.',
  listTitle: 'Daftar Unit',
  unitDoneSub: 'unit sudah pernah rebearing',
  emptyHint: 'Belum ada unit. Import file rebearing fan drive (.xlsx) lewat web.',
  showDelta: true,
  showWorkType: true,
  planKpi: true,
);

const kFanPompaSpec = ProkerModuleSpec(
  id: 'prokerfandpompa',
  title: 'Proker Fan Drive Pompa',
  introLead: 'Program kerja ',
  introBold: 'Upgrade Pulley Fan Drive Pompa Primer',
  introTail: ' — riwayat upgrade pulley fan drive per unit.',
  listTitle: 'Daftar Unit',
  unitDoneSub: 'unit sudah di-upgrade',
  emptyHint: 'Belum ada unit. Import file upgrade pulley (.xlsx) lewat web.',
  showDelta: true,
  showWorkType: true,
  planKpi: true,
);

const kGmcSpec = ProkerModuleSpec(
  id: 'prokergmc',
  title: 'Proker GMC Motor',
  introLead: 'Program kerja ',
  introBold: 'GMC Motor (2.000 jam)',
  introTail: ' — general maintenance check motor listrik pompa primer.',
  listTitle: 'Daftar Unit',
  unitDoneSub: 'unit sudah pernah GMC',
  emptyHint: 'Belum ada unit. Import file GMC motor (.xlsx) lewat web.',
  showDelta: true,
  showWorkType: true,
  planKpi: true,
);

const kFsBoosterSpec = ProkerModuleSpec(
  id: 'prokerfsbooster',
  title: 'Proker Fire Sup Booster',
  introLead: 'Program kerja ',
  introBold: 'Fire Suppression Booster',
  introTail:
      ' — status pemasangan fire suppression per unit (satu kali jalan, tanpa interval HM).',
  listTitle: 'Daftar Unit',
  unitDoneSub: 'unit sudah terpasang',
  emptyHint:
      'Belum ada unit. Import file FIRE SUPPRESSION BOOSTER (.xlsx) lewat web.',
);

const kFsPrimerSpec = ProkerModuleSpec(
  id: 'prokerfsprimer',
  title: 'Proker Fire Sup Primer',
  introLead: 'Program kerja ',
  introBold: 'Fire Suppression Primer',
  introTail:
      ' — status pemasangan fire suppression pompa primer (satu kali jalan, tanpa interval HM).',
  listTitle: 'Daftar Unit',
  unitDoneSub: 'unit sudah terpasang',
  emptyHint:
      'Belum ada unit. Import file FIRE SUPPRESSION PRIMER (.xlsx) lewat web.',
);

const kPontonSpec = ProkerModuleSpec(
  id: 'prokerponton',
  title: 'Proker Repair Ponton',
  introLead: 'Program kerja ',
  introBold: 'General Repair Ponton (EVERY YEAR)',
  introTail:
      ' — riwayat repair per tahun + kondisi ponton & anoda zink, data dari file Excel.',
  listTitle: 'Daftar Unit',
  unitDoneSub: 'unit sudah pernah proker',
  emptyHint: 'Belum ada unit. Import file GENERAL REPAIR PONTON (.xlsx) lewat web.',
  showPontonFilter: true,
  showWorkType: true,
  planKpi: true,
);

/// Halaman modul proker generik — dipakai 8 spesifikasi di atas.
class ProkerModulePage extends ConsumerStatefulWidget {
  final ProkerModuleSpec spec;
  const ProkerModulePage({super.key, required this.spec});

  @override
  ConsumerState<ProkerModulePage> createState() => _ProkerModulePageState();
}

class _ProkerModulePageState extends ConsumerState<ProkerModulePage> {
  final _searchCtl = TextEditingController();
  Timer? _debounce;
  bool _refreshing = false;

  ProkerModuleSpec get _spec => widget.spec;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _apply(q: v.trim());
    });
  }

  void _apply({
    String? q,
    String? product,
    String? model,
    String? ponton,
    String? executed,
  }) =>
      ref
          .read(moduleFilterProviders[_spec.id]!.notifier)
          .apply(
            q: q,
            product: product,
            model: model,
            ponton: ponton,
            executed: executed,
          );

  void _reset() {
    _searchCtl.clear();
    _apply(q: '', product: '', model: '', ponton: '', executed: '');
  }

  Future<void> _refreshHm() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final res = await ref.read(prokerApiProvider).moduleRefreshHm(_spec.id);
      invalidateModuleData(ref, _spec.id);
      if (mounted) {
        prokerSnack(
            context,
            'Refresh HM selesai: ${res.updated} unit diperbarui · '
            '${res.unchanged} sudah terbaru · '
            '${res.notFound} tidak ditemukan di sumber data');
      }
    } catch (e) {
      if (mounted) prokerSnack(context, 'Refresh HM gagal: $e');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(moduleFilterProviders[_spec.id]!);
    final statsAsync = ref.watch(moduleStatsProvider(_spec.id));
    final filtersAsync = ref.watch(moduleFiltersProvider(_spec.id));
    final unitsAsync = ref.watch(moduleUnitsProvider(_spec.id));
    final canAdd = ref.watch(authProvider).can(_spec.id, 'add');

    return AppScaffold(
      title: _spec.title,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(moduleStatsProvider(_spec.id));
          ref.invalidate(moduleFiltersProvider(_spec.id));
          ref.invalidate(moduleUnitsProvider(_spec.id));
          await ref.read(moduleUnitsProvider(_spec.id).future);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _statsSection(statsAsync),
            const SizedBox(height: 8),
            _filterSection(filtersAsync.value, f, canAdd, unitsAsync.value),
            const SizedBox(height: 8),
            _unitsSection(unitsAsync),
          ],
        ),
      ),
    );
  }

  // ── Pengantar + KPI 4 kartu (paritas web) ─────────────────────────
  Widget _statsSection(AsyncValue<ProkerStats> a) => a.when(
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: _spec.introLead),
                TextSpan(
                    text: _spec.introBold,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: _spec.introTail),
              ]),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            prokerKpiGrid([
              KpiCard(
                  label: 'Unit aktif',
                  value: fmtNum(s.units),
                  color: prokerBrand,
                  sub: '${fmtNum(s.unitDone)} ${_spec.unitDoneSub}'),
              KpiCard(
                  label: 'Total eksekusi',
                  value: fmtNum(s.total),
                  color: prokerGray,
                  sub: '${fmtNum(s.done)} selesai'),
              KpiCard(
                  label: 'Tahun ${s.year}',
                  value: fmtNum(s.thisYear),
                  color: prokerGreen,
                  sub: 'eksekusi selesai'),
              if (_spec.planKpi)
                KpiCard(
                    label: 'Rencana / terlewat',
                    value: '${fmtNum(s.plan)} / ${fmtNum(s.missed)}',
                    color: prokerAmber,
                    sub: 'terakhir: ${fmtDateDash(s.lastDate)}')
              else
                KpiCard(
                    label: 'Belum (NOT YET)',
                    value: fmtNum(s.notYet),
                    color: prokerAmber,
                    sub: 'terakhir: ${fmtDateDash(s.lastDate)}'),
            ]),
          ],
        ),
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Memuat ringkasan…',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ),
        error: (e, _) => Text('Gagal memuat ringkasan: $e',
            style: const TextStyle(fontSize: 11, color: prokerRed)),
      );

  // ── Filter + chip cakupan eksekusi ────────────────────────────────
  Widget _filterSection(ProkerFilters? filters, ModuleFilter f, bool canAdd,
      ListPage<ProkerUnit>? units) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchCtl,
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Cari unit',
                hintText: 'C/N / model / product',
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search, size: 18),
                labelStyle: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                FilterDropdown(
                  label: 'Product',
                  value: f.product,
                  items: filters?.product ?? const [],
                  onChanged: (v) => _apply(product: v),
                ),
                FilterDropdown(
                  label: 'Unit model',
                  value: f.model,
                  items: filters?.model ?? const [],
                  onChanged: (v) => _apply(model: v),
                ),
                if (_spec.showPontonFilter)
                  FilterDropdown(
                    label: 'Tipe ponton',
                    value: f.ponton,
                    items: filters?.ponton ?? const [],
                    onChanged: (v) => _apply(ponton: v),
                  ),
                OutlinedButton(
                  onPressed: _reset,
                  child: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
                if (canAdd)
                  OutlinedButton.icon(
                    onPressed: _refreshing ? null : _refreshHm,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(_refreshing ? 'Refresh…' : 'Refresh HM',
                        style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                _execChip(
                  label: 'Semua',
                  n: units?.total,
                  selected: f.executed.isEmpty,
                  onTap: () => _apply(executed: ''),
                ),
                _execChip(
                  label: 'Sudah proker',
                  n: units?.executedUnits,
                  selected: f.executed == 'yes',
                  onTap: () => _apply(executed: 'yes'),
                ),
                _execChip(
                  label: 'Belum proker',
                  n: units?.notExecutedUnits,
                  selected: f.executed == 'no',
                  onTap: () => _apply(executed: 'no'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _execChip({
    required String label,
    required int? n,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      ChoiceChip(
        label: Text(n == null ? label : '$label ($n)',
            style: const TextStyle(fontSize: 11)),
        selected: selected,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onTap(),
      );

  // ── Daftar unit + pagination ──────────────────────────────────────
  Widget _unitsSection(AsyncValue<ListPage<ProkerUnit>> a) {
    final p = a.value;
    final f = ref.read(moduleFilterProviders[_spec.id]!);
    final provider = moduleFilterProviders[_spec.id]!;
    final page = p?.page ?? 1;
    final totalPages = p == null
        ? 1
        : ((p.total / prokerPageSize).ceil()).clamp(1, 1 << 31);
    return SectionCard(
      title: _spec.listTitle,
      subtitle: p == null
          ? null
          : '${fmtNum(p.total)} unit · hal $page/$totalPages',
      trailing: p == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      page <= 1 ? null : () => ref.read(provider.notifier).setPage(page - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: page >= totalPages
                      ? null
                      : () => ref.read(provider.notifier).setPage(page + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
      child: a.when(
        data: (p) => p.data.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    f.executed == 'no' && p.total > 0
                        ? 'Semua unit pada filter ini sudah pernah proker.'
                        : _spec.emptyHint,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Column(
                children: [
                  for (final u in p.data)
                    UnitTile(
                      cn: u.cn,
                      model: u.modelLabel,
                      sub: _spec.showPontonFilter
                          ? (u.typePonton ?? u.productTypeLabel)
                          : u.productTypeLabel,
                      onTap: () => showProkerSheet(
                          context, _ModuleDetail(spec: _spec, cn: u.cn)),
                      trailing: [
                        tileValue(fmtHm(u.hmNow)),
                        tileNote('HM now'),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: tileNote(
                            '${u.execCount} proker · ${fmtDateDash(u.lastDate)}',
                          ),
                        ),
                      ],
                    ),
                ],
              ),
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Column(
              children: [
                Text('$e',
                    style: const TextStyle(color: prokerRed, fontSize: 12),
                    textAlign: TextAlign.center),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(moduleUnitsProvider(_spec.id)),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Detail unit (bottom sheet) ──────────────────────

class _ModuleDetail extends ConsumerWidget {
  final ProkerModuleSpec spec;
  final String cn;
  const _ModuleDetail({required this.spec, required this.cn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(moduleDetailProvider('${spec.id}|$cn'));
    return a.when(
      data: (d) => _detailBody(d),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: '$e',
        onRetry: () => ref.invalidate(moduleDetailProvider('${spec.id}|$cn')),
      ),
    );
  }

  Widget _detailBody(ProkerDetail d) {
    final s = d.stats;
    final deltas = computeExecDeltas(d.executions);
    final boxes = <Widget>[
      StatBox(
          label: 'Total proker',
          value: fmtNum(s.total),
          sub: '${fmtNum(s.done)} selesai'),
      StatBox(
          label: 'HM sekarang',
          value: fmtHm(d.unit.hmNow),
          sub: 'Refresh HM'),
      StatBox(
          label: 'Terakhir',
          value: s.lastHm == null ? fmtDateDash(s.lastDate) : fmtHm(s.lastHm),
          sub: s.lastHm == null ? 'HM belum dicatat' : fmtDateDash(s.lastDate)),
    ];
    if (spec.showDelta && s.interval != null) {
      boxes.add(StatBox(
        label: 'Sisa ke ${fmtNum(s.interval)} jam',
        value: s.sisaHm == null ? '-' : fmtHm(s.sisaHm),
        valueColor:
            s.sisaHm != null && s.sisaHm! <= 0 ? prokerRed : prokerGreen,
        sub: 'target HM ${fmtHm(s.dueHm)}',
      ));
    } else if (spec.showPontonFilter) {
      boxes.add(StatBox(
          label: 'Tipe ponton',
          value: d.unit.typePonton ?? '-',
          sub: d.unit.kondisi ?? ''));
    } else {
      boxes.add(StatBox(
          label: 'Jenis',
          value: d.executions.isEmpty ? '-' : d.executions.first.workType,
          sub: 'jenis pekerjaan terakhir'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        DetailHead(
          cn: d.unit.cn,
          subtitle: '${d.unit.modelLabel} · ${d.unit.product ?? '-'} · '
              '${d.unit.unitType ?? '-'}',
        ),
        const SizedBox(height: 12),
        prokerKpiGrid(boxes),
        if (spec.showPontonFilter && (d.unit.typeDetail ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Detail tipe: ${d.unit.typeDetail}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ),
        const SizedBox(height: 14),
        const Text('Riwayat proker',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (d.executions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text('Belum ada riwayat proker untuk unit ini.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          )
        else
          prokerTable(
            columns: [
              const DataColumn(label: Text('Periode')),
              if (spec.showWorkType)
                const DataColumn(label: Text('Jenis')),
              const DataColumn(label: Text('Tanggal')),
              const DataColumn(label: Text('HM'), numeric: true),
              if (spec.showDelta)
                const DataColumn(label: Text('Δ HM'), numeric: true),
              const DataColumn(label: Text('Catatan')),
              const DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final e in d.executions)
                DataRow(cells: [
                  DataCell(Text(e.period)),
                  if (spec.showWorkType)
                    DataCell(_workTypeCell(e.workType)),
                  DataCell(Text(fmtDateDash(e.serviceDate))),
                  DataCell(Text(fmtHm(e.hm))),
                  if (spec.showDelta)
                    DataCell(Text(
                      fmtSigned(deltas[e.id]),
                      style: TextStyle(
                          color: (deltas[e.id] ?? 0) < 0
                              ? prokerRed
                              : Colors.grey.shade600),
                    )),
                  DataCell(SizedBox(
                    width: 140,
                    child: Text(e.mekanik ?? '-',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  )),
                  DataCell(_statusBadge(e.status)),
                ]),
            ],
          ),
      ],
    );
  }

  Widget _workTypeCell(String workType) {
    if (workType.toUpperCase() == 'ANODA ZINK') {
      return const PillBadge(label: 'Anoda Zink', bg: _blueBg, fg: _blueFg);
    }
    return SizedBox(
      width: 130,
      child: Text(workType.isEmpty ? '-' : workType,
          maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

const _blueBg = Color(0xFFD1E9FF);
const _blueFg = Color(0xFF175CD3);
const _grayBg = Color(0xFFEAECF0);
const _grayFg = Color(0xFF344054);

/// Badge status lengkap: DONE/PLAN/LATE/MISSED (web Proker) + NOT YET/NA/NOTE
/// (modul fire suppression & ponton).
PillBadge _statusBadge(String status) => switch (status.toUpperCase()) {
      'NOT YET' => const PillBadge(label: 'Belum', bg: _grayBg, fg: _grayFg),
      'NA' => const PillBadge(label: 'Tdk berlaku', bg: _grayBg, fg: _grayFg),
      'NOTE' => const PillBadge(label: 'Catatan', bg: _blueBg, fg: _blueFg),
      _ => prokerStatusBadge(status),
    };

// ─────────────────────────── 8 halaman publik ──────────────────────────────

class ProkerExhaustPage extends StatelessWidget {
  const ProkerExhaustPage({super.key});
  @override
  Widget build(BuildContext context) =>
      ProkerModulePage(spec: kExhaustSpec);
}

class ProkerExhaustMitsPage extends StatelessWidget {
  const ProkerExhaustMitsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      ProkerModulePage(spec: kExhaustMitsSpec);
}

class ProkerFanDriveRebbPage extends StatelessWidget {
  const ProkerFanDriveRebbPage({super.key});
  @override
  Widget build(BuildContext context) =>
      ProkerModulePage(spec: kFanDriveRebbSpec);
}

class ProkerFanPompaPage extends StatelessWidget {
  const ProkerFanPompaPage({super.key});
  @override
  Widget build(BuildContext context) =>
      ProkerModulePage(spec: kFanPompaSpec);
}

class ProkerGmcPage extends StatelessWidget {
  const ProkerGmcPage({super.key});
  @override
  Widget build(BuildContext context) => ProkerModulePage(spec: kGmcSpec);
}

class ProkerFireSupBoosterPage extends StatelessWidget {
  const ProkerFireSupBoosterPage({super.key});
  @override
  Widget build(BuildContext context) =>
      ProkerModulePage(spec: kFsBoosterSpec);
}

class ProkerFireSupPrimerPage extends StatelessWidget {
  const ProkerFireSupPrimerPage({super.key});
  @override
  Widget build(BuildContext context) =>
      ProkerModulePage(spec: kFsPrimerSpec);
}

class ProkerPontonPage extends StatelessWidget {
  const ProkerPontonPage({super.key});
  @override
  Widget build(BuildContext context) => ProkerModulePage(spec: kPontonSpec);
}
