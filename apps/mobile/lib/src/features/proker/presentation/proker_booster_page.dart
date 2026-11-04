// Halaman Proker Midlife Eng Booster — paritas tampilan web ProkerBooster.tsx:
// filter (+ "hanya jatuh tempo"), KPI, daftar unit, detail riwayat OVH/Midlife.
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

class ProkerBoosterPage extends ConsumerStatefulWidget {
  const ProkerBoosterPage({super.key});

  @override
  ConsumerState<ProkerBoosterPage> createState() => _ProkerBoosterPageState();
}

class _ProkerBoosterPageState extends ConsumerState<ProkerBoosterPage> {
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
      ref.read(boosterFilterProvider.notifier).apply(q: v.trim());
    });
  }

  void _reset() {
    _searchCtl.clear();
    ref
        .read(boosterFilterProvider.notifier)
        .apply(q: '', product: '', model: '', due: false);
  }

  Future<void> _refreshHm() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final res = await ref.read(prokerApiProvider).boosterRefreshHm();
      invalidateBoosterData(ref);
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
    final f = ref.watch(boosterFilterProvider);
    final kpiAsync = ref.watch(boosterKpiProvider);
    final filtersAsync = ref.watch(boosterFiltersProvider);
    final unitsAsync = ref.watch(boosterUnitsProvider);
    final canAdd = ref.watch(authProvider).can('prokerbooster', 'add');

    return AppScaffold(
      title: 'Proker Midlife Eng Booster',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(boosterKpiProvider);
          ref.invalidate(boosterFiltersProvider);
          ref.invalidate(boosterUnitsProvider);
          await ref.read(boosterUnitsProvider.future);
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

  Widget _statsSection(AsyncValue<BoosterKpi> a, BoosterFilters? filters) {
    final interval = a.value?.interval ?? filters?.interval ?? 20000;
    return a.when(
      data: (k) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Program kerja '),
              const TextSpan(
                  text: 'Midlife Engine pompa booster',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(
                  text:
                      ' — interval ${fmtNum(interval)} jam, berisi riwayat OVH dan midlife engine.'),
            ]),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          prokerKpiGrid([
            KpiCard(
                label: 'Unit booster',
                value: fmtNum(k.units),
                color: prokerBrand,
                sub: '${fmtNum(k.unitEvent)} unit punya riwayat'),
            KpiCard(
                label: 'Event engine',
                value: fmtNum(k.total),
                color: prokerGray,
                sub: '${fmtNum(k.ovh)} OVH · ${fmtNum(k.midlife)} midlife'),
            KpiCard(
                label: 'Jatuh tempo',
                value: fmtNum(k.due),
                color: k.due > 0 ? prokerRed : prokerGreen,
                sub: 'unit sisa ≤ 0 jam'),
            KpiCard(
                label: 'Event terakhir',
                value: fmtDateDash(k.lastDate),
                color: prokerGray,
                sub: 'dari data terakhir'),
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
      BoosterFilters? filters, ProkerUnitFilter f, bool canAdd) {
    final notifier = ref.read(boosterFilterProvider.notifier);
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
                hintText: 'C/N / model / product / catatan',
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

  Widget _unitsSection(AsyncValue<ListPage<BoosterUnit>> a) {
    final p = a.value;
    final page = p?.page ?? 1;
    final totalPages = p == null
        ? 1
        : ((p.total / prokerPageSize).ceil()).clamp(1, 1 << 31);
    final notifier = ref.read(boosterFilterProvider.notifier);
    return SectionCard(
      title: 'Daftar Unit Booster',
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
                    'Belum ada unit booster. Import file ".xlsx" lewat web.',
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
                          showProkerSheet(context, _BoosterDetail(cn: u.cn)),
                      trailing: [
                        tileValue(fmtHm(u.hmNow)),
                        tileNote('HM now'),
                        tileValue(
                          fmtSigned(u.hoursToGo),
                          color: dueLevelColor(dueLevel(u.hoursToGo)),
                        ),
                        tileNote('Sisa jam'),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: tileNote(
                            u.lastKind == null
                                ? '${u.eventCount} event'
                                : '${u.eventCount} event · '
                                    '${boosterKindLabel(u.lastKind)} '
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
                  onPressed: () => ref.invalidate(boosterUnitsProvider),
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

class _BoosterDetail extends ConsumerWidget {
  final String cn;
  const _BoosterDetail({required this.cn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(boosterDetailProvider(cn));
    return a.when(
      data: (d) => _detailBody(context, d),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: '$e',
        onRetry: () => ref.invalidate(boosterDetailProvider(cn)),
      ),
    );
  }

  Widget _detailBody(BuildContext context, BoosterDetail d) {
    final s = d.stats;
    final remarks = d.unit.remarks;
    final deltas = computeEventDeltas(d.events);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        DetailHead(
          cn: d.unit.cn,
          subtitle: '${d.unit.modelLabel} · ${d.unit.product ?? '-'} · '
              '${d.unit.unitType ?? '-'}',
          extra: remarks == null ? null : remarkBadge(remarks),
        ),
        const SizedBox(height: 12),
        prokerKpiGrid([
          StatBox(
              label: 'HM sekarang',
              value: fmtHm(d.unit.hmNow),
              sub: 'HM NOW di file'),
          StatBox(
              label: 'Target berikutnya',
              value: fmtHm(s.nextPlanHm),
              sub: 'event terakhir + ${fmtNum(s.intervalHm)} jam'),
          StatBox(
              label: 'Sisa jam',
              value: fmtSigned(s.hoursToGo),
              valueColor: dueLevelColor(dueLevel(s.hoursToGo)),
              sub: s.due ? 'sudah jatuh tempo' : 'masih ada waktu'),
          StatBox(
              label: 'Lifetime EG',
              value: fmtHm(s.lifetimeEg),
              sub: 'midlife ${s.lifetimeMid == null ? '-' : fmtHm(s.lifetimeMid)} jam'),
        ]),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MiniInfo(
                dotColor: const Color(0xFF175CD3),
                label: 'OVH terakhir',
                value: fmtHm(d.unit.ovhHm),
                sub: fmtDateDash(d.unit.ovhDate),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MiniInfo(
                dotColor: const Color(0xFF12B76A),
                label: 'Midlife terakhir',
                value: fmtHm(d.unit.mlHm),
                sub: fmtDateDash(d.unit.mlDate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text('Riwayat OVH / Midlife',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (d.events.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text('Belum ada riwayat OVH / midlife untuk unit ini.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          )
        else
          prokerTable(
            columns: const [
              DataColumn(label: Text('Jenis')),
              DataColumn(label: Text('Tanggal')),
              DataColumn(label: Text('HM'), numeric: true),
              DataColumn(label: Text('Δ HM'), numeric: true),
              DataColumn(label: Text('Catatan')),
            ],
            rows: [
              for (final e in d.events)
                DataRow(cells: [
                  DataCell(boosterKindBadge(e.kind)),
                  DataCell(Text(fmtDateDash(e.serviceDate))),
                  DataCell(Text(fmtHm(e.hm))),
                  DataCell(Text(fmtSigned(deltas[e.id]),
                      style: TextStyle(color: Colors.grey.shade600))),
                  DataCell(SizedBox(
                    width: 170,
                    child: Text(e.note ?? '-',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  )),
                ]),
            ],
          ),
      ],
    );
  }
}
