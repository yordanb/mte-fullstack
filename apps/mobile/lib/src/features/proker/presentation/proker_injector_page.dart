// Halaman Proker Midlife Injector Primer — paritas tampilan web
// ProkerInjector.tsx: filter (+ jatuh tempo), KPI, daftar unit, detail
// grid 12 posisi injector + riwayat penggantian per nomor penggantian.
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

class ProkerInjectorPage extends ConsumerStatefulWidget {
  const ProkerInjectorPage({super.key});

  @override
  ConsumerState<ProkerInjectorPage> createState() => _ProkerInjectorPageState();
}

class _ProkerInjectorPageState extends ConsumerState<ProkerInjectorPage> {
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
      ref.read(injectorFilterProvider.notifier).apply(q: v.trim());
    });
  }

  void _reset() {
    _searchCtl.clear();
    ref
        .read(injectorFilterProvider.notifier)
        .apply(q: '', product: '', model: '', due: false);
  }

  Future<void> _refreshHm() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final res = await ref.read(prokerApiProvider).injectorRefreshHm();
      invalidateInjectorData(ref);
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
    final f = ref.watch(injectorFilterProvider);
    final kpiAsync = ref.watch(injectorKpiProvider);
    final filtersAsync = ref.watch(injectorFiltersProvider);
    final unitsAsync = ref.watch(injectorUnitsProvider);
    final canAdd = ref.watch(authProvider).can('prokerinjector', 'add');

    return AppScaffold(
      title: 'Proker Midlife Injector Primer',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(injectorKpiProvider);
          ref.invalidate(injectorFiltersProvider);
          ref.invalidate(injectorUnitsProvider);
          await ref.read(injectorUnitsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _statsSection(kpiAsync, filtersAsync.value),
            const SizedBox(height: 8),
            _filterSection(filtersAsync.value, f, canAdd),
            const SizedBox(height: 8),
            _unitsSection(unitsAsync),
          ],
        ),
      ),
    );
  }

  Widget _statsSection(AsyncValue<InjectorKpi> a, InjectorFilters? filters) {
    final interval = a.value?.interval ?? filters?.interval ?? 16000;
    final positions = a.value?.positions ?? filters?.positions ?? 12;
    return a.when(
      data: (k) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Program kerja '),
              const TextSpan(
                  text: 'Replace Injector Primer',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(
                  text:
                      ' — umur injector ${fmtNum(interval)} jam, $positions posisi per unit.'),
            ]),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          prokerKpiGrid([
            KpiCard(
                label: 'Unit primer',
                value: fmtNum(k.units),
                color: prokerBrand,
                sub: '${fmtNum(k.unitWithRepl)} unit punya riwayat'),
            KpiCard(
                label: 'Baris penggantian',
                value: fmtNum(k.total),
                color: prokerGray,
                sub: '${fmtNum(k.done)} terpasang · ${fmtNum(k.plan)} rencana'),
            KpiCard(
                label: 'Jatuh tempo',
                value: fmtNum(k.due),
                color: k.due > 0 ? prokerRed : prokerGreen,
                sub: 'umur ≥ ${fmtNum(k.interval)} jam'),
            KpiCard(
                label: 'Belum ada riwayat',
                value: fmtNum((k.units - k.unitWithRepl).clamp(0, 1 << 31)),
                color: Colors.grey.shade600,
                sub: 'unit tanpa catatan penggantian'),
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
  }

  Widget _filterSection(
      InjectorFilters? filters, ProkerUnitFilter f, bool canAdd) {
    final notifier = ref.read(injectorFilterProvider.notifier);
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
                hintText: 'C/N / model / product',
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
              crossAxisAlignment: WrapCrossAlignment.center,
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
                FilterChip(
                  label: const Text('Hanya jatuh tempo',
                      style: TextStyle(fontSize: 11.5)),
                  selected: f.due,
                  onSelected: (v) => notifier.apply(due: v),
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

  Widget _unitsSection(AsyncValue<ListPage<InjectorUnit>> a) {
    final p = a.value;
    final page = p?.page ?? 1;
    final totalPages = p == null
        ? 1
        : ((p.total / prokerPageSize).ceil()).clamp(1, 1 << 31);
    final notifier = ref.read(injectorFilterProvider.notifier);
    final interval = ref.watch(injectorKpiProvider).value?.interval ??
        ref.watch(injectorFiltersProvider).value?.interval ??
        16000;
    return SectionCard(
      title: 'Daftar Unit Primer',
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
                    'Belum ada unit primer. Import file ".xlsx" lewat web.',
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
                          showProkerSheet(context, _InjectorDetail(cn: u.cn)),
                      trailing: [
                        tileValue(fmtHm(u.hmNow)),
                        tileNote('HM now'),
                        tileValue(
                          fmtHm(u.ageHm),
                          color: dueLevelColor(injectorAgeLevel(u.ageHm, interval)),
                        ),
                        tileNote('Umur'),
                        tileValue(
                          fmtSigned(u.hoursToGo),
                          color: dueLevelColor(injectorAgeLevel(u.ageHm, interval)),
                        ),
                        tileNote('Sisa jam'),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: tileNote(
                            'P${u.lastSeq ?? '-'} · '
                            '${u.replCount > 0 ? '${u.doneCount} terpasang' : 'belum ada'}',
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
                  onPressed: () => ref.invalidate(injectorUnitsProvider),
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

class _InjectorDetail extends ConsumerWidget {
  final String cn;
  const _InjectorDetail({required this.cn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(injectorDetailProvider(cn));
    return a.when(
      data: (d) => _detailBody(context, d),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: '$e',
        onRetry: () => ref.invalidate(injectorDetailProvider(cn)),
      ),
    );
  }

  Widget _detailBody(BuildContext context, InjectorDetail d) {
    final s = d.stats;
    final interval = s.intervalHm;
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
              label: 'HM sekarang',
              value: fmtHm(d.unit.hmNow),
              sub: 'HM NOW di file'),
          StatBox(
              label: 'Penggantian terakhir',
              value: s.lastSeq == null
                  ? '-'
                  : 'P${s.lastSeq} · ${fmtHm(s.lastHm)}',
              sub: s.lastHm == null
                  ? 'belum ada data HM'
                  : '${fmtNum(s.done)} baris terpasang'),
          StatBox(
              label: 'Umur injector',
              value: fmtHm(s.ageHm),
              valueColor: dueLevelColor(injectorAgeLevel(s.ageHm, interval)),
              sub: 'dari HM penggantian terakhir'),
          StatBox(
              label: 'Sisa jam',
              value: fmtSigned(s.hoursToGo),
              valueColor: dueLevelColor(injectorAgeLevel(s.ageHm, interval)),
              sub: s.ageHm == null
                  ? 'belum bisa dihitung'
                  : s.due
                      ? 'sudah lewat ${fmtNum(interval)} jam'
                      : 'target ${fmtHm(s.nextPlanHm)}'),
        ]),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Posisi injector (P terakhir per posisi)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              'hijau < 80% · kuning ≥ 80% · merah ≥ ${fmtNum(interval)} jam',
              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.95,
          children: [
            for (final p in d.positions) _posCell(context, p, interval),
          ],
        ),
        const SizedBox(height: 14),
        const Text('Riwayat penggantian',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (d.replacements.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text('Belum ada riwayat penggantian injector untuk unit ini.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          )
        else
          prokerTable(
            columns: const [
              DataColumn(label: Text('Penggantian')),
              DataColumn(label: Text('Posisi')),
              DataColumn(label: Text('HM'), numeric: true),
              DataColumn(label: Text('Umur'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Catatan')),
            ],
            rows: _replRows(d, interval),
          ),
      ],
    );
  }

  Widget _posCell(BuildContext context, InjectorPosition p, num interval) {
    final level = posLevel(p, interval);
    final (bg, border) = switch (level) {
      PosLevel.plan => (const Color(0xFFFFFAEB), const Color(0xFFFEDF89)),
      PosLevel.bad => (const Color(0xFFFEF3F2), const Color(0xFFFECDCA)),
      PosLevel.warn => (const Color(0xFFFFFAEB), const Color(0xFFFEDF89)),
      PosLevel.ok => (const Color(0xFFECFDF3), const Color(0xFFABEFC6)),
      PosLevel.empty => (
          Theme.of(context).colorScheme.surface,
          Theme.of(context).dividerColor
        ),
    };
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text('#${p.position}',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
              const Spacer(),
              if (p.seq != null)
                Text('P${p.seq}',
                    style:
                        TextStyle(fontSize: 9.5, color: Colors.grey.shade500)),
            ],
          ),
          if (p.status == 'PLAN')
            const Text('RENCANA',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: prokerHeadAmber))
          else
            Text(fmtHm(p.hm),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold)),
          Text(
            p.age == null ? 'umur -' : 'umur ${fmtHm(p.age)}',
            style: TextStyle(
                fontSize: 9.5,
                color: dueLevelColor(injectorAgeLevel(p.age, interval))),
          ),
        ],
      ),
    );
  }

  List<DataRow> _replRows(InjectorDetail d, num interval) {
    final hmNow = d.unit.hmNow;
    final rows = <DataRow>[];
    for (final g in groupReplacements(d.replacements)) {
      for (var i = 0; i < g.rows.length; i++) {
        final r = g.rows[i];
        final age = (hmNow == null || r.hm == null) ? null : hmNow - r.hm!;
        rows.add(DataRow(cells: [
          DataCell(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              injectorSeqBadge(g.seq),
              if (i == 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('${g.rows.length} posisi',
                      style:
                          TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                ),
            ],
          )),
          DataCell(Text('#${r.position}')),
          DataCell(Text(fmtHm(r.hm))),
          DataCell(Text(fmtHm(age),
              style:
                  TextStyle(color: dueLevelColor(injectorAgeLevel(age, interval))))),
          DataCell(injectorStatusBadge(r.status)),
          DataCell(SizedBox(
            width: 130,
            child: Text(r.note ?? '-',
                maxLines: 2, overflow: TextOverflow.ellipsis),
          )),
        ]));
      }
    }
    return rows;
  }
}
