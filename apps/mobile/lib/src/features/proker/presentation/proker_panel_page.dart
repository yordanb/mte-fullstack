// Halaman Proker GMC Panel Booster (2.000 jam) — paritas tampilan web
// ProkerPanel.tsx: filter + KPI + daftar unit + detail riwayat eksekusi (Δ HM).
// Berbeda dari GMC Pompa Primer: TIDAK ada filter engine CAT — semua unit
// (WARMAN / MULTIFLO / KOMATSU, dst) ditampilkan.
// Scope mobile: tampilan + Refresh HM (tanpa form edit/import).
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

class ProkerPanelPage extends ConsumerStatefulWidget {
  const ProkerPanelPage({super.key});

  @override
  ConsumerState<ProkerPanelPage> createState() => _ProkerPanelPageState();
}

class _ProkerPanelPageState extends ConsumerState<ProkerPanelPage> {
  final _searchCtl = TextEditingController();
  Timer? _debounce;
  bool _refreshing = false;

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
      ref.read(panelFilterProvider.notifier).apply(q: v.trim());
    });
  }

  void _reset() {
    _searchCtl.clear();
    ref
        .read(panelFilterProvider.notifier)
        .apply(q: '', product: '', model: '');
  }

  Future<void> _refreshHm() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final res = await ref.read(prokerApiProvider).panelRefreshHm();
      invalidatePanelData(ref);
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
    final f = ref.watch(panelFilterProvider);
    final statsAsync = ref.watch(panelStatsProvider);
    final filtersAsync = ref.watch(panelFiltersProvider);
    final unitsAsync = ref.watch(panelUnitsProvider);
    final canAdd = ref.watch(authProvider).can('prokerpanel', 'add');

    return AppScaffold(
      title: 'Proker GMC Panel Booster',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(panelStatsProvider);
          ref.invalidate(panelFiltersProvider);
          ref.invalidate(panelUnitsProvider);
          await ref.read(panelUnitsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _statsSection(statsAsync),
            const SizedBox(height: 8),
            _filterSection(filtersAsync.value, f, canAdd),
            const SizedBox(height: 8),
            _unitsSection(unitsAsync),
          ],
        ),
      ),
    );
  }

  // ── Pengantar + KPI (web ProkerPanel.tsx KPI 4 kartu) ───────────
  Widget _statsSection(AsyncValue<ProkerStats> a) => a.when(
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Program kerja '),
                const TextSpan(
                    text: 'GMC Panel Booster (2.000 jam)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(
                    text: ' — data dari file Excel, dapat diperbarui '
                        'lewat Import Excel.'),
              ]),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            prokerKpiGrid([
              KpiCard(
                  label: 'Total unit',
                  value: fmtNum(s.units),
                  color: prokerBrand,
                  sub: '${fmtNum(s.unitDone)} unit sudah pernah proker'),
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
              KpiCard(
                  label: 'Rencana / terlewat',
                  value: '${fmtNum(s.plan)} / ${fmtNum(s.missed)}',
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

  // ── Filter: cari + product + model + Reset + Refresh HM ─────────
  Widget _filterSection(ProkerFilters? filters, PanelFilter f, bool canAdd) {
    final notifier = ref.read(panelFilterProvider.notifier);
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
              decoration: InputDecoration(
                labelText: 'Cari unit',
                hintText: 'C/N / model / product / type',
                isDense: true,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search, size: 18),
                labelStyle: const TextStyle(fontSize: 12),
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
                  onChanged: (v) => notifier.apply(product: v),
                ),
                FilterDropdown(
                  label: 'Unit model',
                  value: f.model,
                  items: filters?.model ?? const [],
                  onChanged: (v) => notifier.apply(model: v),
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
          ],
        ),
      ),
    );
  }

  // ── Daftar unit + pagination ────────────────────────────────────
  Widget _unitsSection(AsyncValue<ListPage<ProkerUnit>> a) {
    final p = a.value;
    final page = p?.page ?? 1;
    final totalPages = p == null
        ? 1
        : ((p.total / prokerPageSize).ceil()).clamp(1, 1 << 31);
    final notifier = ref.read(panelFilterProvider.notifier);
    return SectionCard(
      title: 'Daftar Unit',
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
                      page <= 1 ? null : () => notifier.setPage(page - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: page >= totalPages
                      ? null
                      : () => notifier.setPage(page + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
      child: a.when(
        data: (p) => p.data.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Belum ada unit. Import file GMC PANEL BOOSTER '
                    '(2.000 HOURS) (.xlsx) lewat web.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
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
                      sub: u.productTypeLabel,
                      onTap: () =>
                          showProkerSheet(context, _PanelDetail(cn: u.cn)),
                      trailing: [
                        tileValue(fmtHm(u.hmNow)),
                        tileNote('HM now'),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: tileNote(
                            '${u.execCount} proker · '
                            '${fmtDateDash(u.lastDate)}',
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
                  onPressed: () => ref.invalidate(panelUnitsProvider),
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

class _PanelDetail extends ConsumerWidget {
  final String cn;
  const _PanelDetail({required this.cn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(panelDetailProvider(cn));
    return a.when(
      data: (d) => _detailBody(context, d),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: '$e',
        onRetry: () => ref.invalidate(panelDetailProvider(cn)),
      ),
    );
  }

  Widget _detailBody(BuildContext context, ProkerDetail d) {
    final s = d.stats;
    final deltas = computeExecDeltas(d.executions);
    final sisa = s.sisaHm;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        DetailHead(
          cn: d.unit.cn,
          subtitle: '${d.unit.modelLabel} · ${d.unit.product ?? '-'} · '
              '${d.unit.unitType ?? '-'}',
        ),
        const SizedBox(height: 12),
        prokerKpiGrid([
          StatBox(
              label: 'Total proker',
              value: fmtNum(s.total),
              sub: '${fmtNum(s.plan)} rencana'),
          StatBox(
              label: 'HM sekarang',
              value: fmtHm(d.unit.hmNow),
              sub: 'HM NOW di file'),
          StatBox(
              label: 'Proker terakhir',
              value: fmtHm(s.lastHm),
              sub: fmtDateDash(s.lastDate)),
          StatBox(
              label: 'Sisa ke ${fmtNum(s.interval)} jam',
              value: sisa == null ? '-' : fmtHm(sisa),
              valueColor: sisa != null && sisa <= 0
                  ? prokerRed
                  : prokerGreen,
              sub: 'target HM ${fmtHm(s.dueHm)}'),
        ]),
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
            columns: const [
              DataColumn(label: Text('Periode')),
              DataColumn(label: Text('Tanggal')),
              DataColumn(label: Text('HM'), numeric: true),
              DataColumn(label: Text('Δ HM'), numeric: true),
              DataColumn(label: Text('Mekanik')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final e in d.executions)
                DataRow(cells: [
                  DataCell(Text(e.period)),
                  DataCell(Text(fmtDateDash(e.serviceDate))),
                  DataCell(Text(fmtHm(e.hm))),
                  DataCell(Text(
                    fmtSigned(deltas[e.id]),
                    style: TextStyle(
                        color: (deltas[e.id] ?? 0) < 0
                            ? prokerRed
                            : Colors.grey.shade600),
                  )),
                  DataCell(SizedBox(
                    width: 150,
                    child: Text(e.mekanik ?? '-',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  )),
                  DataCell(prokerStatusBadge(e.status)),
                ]),
            ],
          ),
      ],
    );
  }
}
