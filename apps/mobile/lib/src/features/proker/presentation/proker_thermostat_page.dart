// Halaman Proker Thermostat CAT — paritas tampilan web Thermostat.tsx:
// filter (+ jatuh tempo), KPI, daftar unit, detail HM/deviasi/lifetime/modif
// 74°C + radiator check. Detail diambil dari unit terpilih pada daftar
// (tidak ada endpoint detail terpisah).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../data/proker_api.dart';
import '../domain/proker_models.dart';
import 'proker_providers.dart';
import 'proker_widgets.dart';

class ProkerThermostatPage extends ConsumerStatefulWidget {
  const ProkerThermostatPage({super.key});

  @override
  ConsumerState<ProkerThermostatPage> createState() =>
      _ProkerThermostatPageState();
}

class _ProkerThermostatPageState extends ConsumerState<ProkerThermostatPage> {
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
      ref.read(thermoFilterProvider.notifier).apply(q: v.trim());
    });
  }

  void _reset() {
    _searchCtl.clear();
    ref
        .read(thermoFilterProvider.notifier)
        .apply(q: '', product: '', model: '', due: false);
  }

  Future<void> _refreshHm() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final res = await ref.read(prokerApiProvider).thermostatRefreshHm();
      invalidateThermoData(ref);
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
    final f = ref.watch(thermoFilterProvider);
    final kpiAsync = ref.watch(thermoKpiProvider);
    final filtersAsync = ref.watch(thermoFiltersProvider);
    final unitsAsync = ref.watch(thermoUnitsProvider);
    final canAdd = ref.watch(authProvider).can('prokerthermo', 'add');

    return AppScaffold(
      title: 'Proker Thermostat CAT',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(thermoKpiProvider);
          ref.invalidate(thermoFiltersProvider);
          ref.invalidate(thermoUnitsProvider);
          await ref.read(thermoUnitsProvider.future);
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

  Widget _statsSection(
      AsyncValue<ThermostatKpi> a, ThermostatFilters? filters) {
    final interval = a.value?.interval ?? filters?.interval ?? 12000;
    return a.when(
      data: (k) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Program kerja '),
              const TextSpan(
                  text: 'Replace Thermostat Engine Caterpillar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(
                  text:
                      ' — interval ${fmtNum(interval)} jam, modifikasi 74°C dan radiator check by therma.'),
            ]),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          prokerKpiGrid([
            KpiCard(
                label: 'Unit thermostat',
                value: fmtNum(k.units),
                color: prokerBrand,
                sub: 'interval ${fmtNum(k.interval)} jam'),
            KpiCard(
                label: 'Modif 74°C',
                value: fmtNum(k.done),
                color: prokerGreen,
                sub: '${fmtNum(k.notYet)} NOT YET'),
            KpiCard(
                label: 'Jatuh tempo',
                value: fmtNum(k.due),
                color: k.due > 0 ? prokerRed : prokerGreen,
                sub: 'deviasi ≥ 0 jam'),
            KpiCard(
                label: 'Ganti thermostat terakhir',
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
      ThermostatFilters? filters, ProkerUnitFilter f, bool canAdd) {
    final notifier = ref.read(thermoFilterProvider.notifier);
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
                hintText: 'C/N / model / product / WR',
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

  Widget _unitsSection(AsyncValue<ListPage<ThermostatUnit>> a) {
    final p = a.value;
    final page = p?.page ?? 1;
    final totalPages = p == null
        ? 1
        : ((p.total / prokerPageSize).ceil()).clamp(1, 1 << 31);
    final notifier = ref.read(thermoFilterProvider.notifier);
    return SectionCard(
      title: 'Daftar Unit Thermostat',
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
                    'Belum ada unit. Import file thermostat ".xlsx" lewat web.',
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
                          showProkerSheet(context, _ThermoDetail(unit: u)),
                      trailing: [
                        tileValue(fmtHm(u.hmNow)),
                        tileNote('HM now'),
                        tileValue(
                          fmtSigned(u.deviasi),
                          color: dueLevelColor(thermoDeviasiLevel(u.deviasi)),
                        ),
                        tileNote('Deviasi'),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              thermoModifBadge(u.modifStatusLabel),
                              const SizedBox(width: 4),
                              tileNote(fmtDateDash(u.modifDate)),
                            ],
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
                  onPressed: () => ref.invalidate(thermoUnitsProvider),
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

class _ThermoDetail extends StatelessWidget {
  final ThermostatUnit unit;
  const _ThermoDetail({required this.unit});

  @override
  Widget build(BuildContext context) {
    final interval = unit.intervalHm;
    final target = unit.hmNow == null
        ? null
        : (unit.lastHm ?? 0) + interval;
    final radHmDate = (unit.radHm == null && unit.radDate == null)
        ? '-'
        : '${fmtHm(unit.radHm)} • ${fmtDateDash(unit.radDate)}';
    final suhu = (unit.radUpper == null && unit.radLower == null)
        ? '-'
        : '↑ ${fmtHm(unit.radUpper)}°C • ↓ ${fmtHm(unit.radLower)}°C';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        DetailHead(
          cn: unit.cn,
          subtitle: '${unit.modelLabel} · ${unit.product ?? '-'} · '
              '${unit.unitType ?? '-'}',
        ),
        const SizedBox(height: 12),
        prokerKpiGrid([
          StatBox(
              label: 'HM sekarang',
              value: fmtHm(unit.hmNow),
              sub: 'HM NOW di file'),
          StatBox(
              label: 'Target ganti',
              value: target == null ? '-' : fmtHm(target),
              sub: 'last + ${fmtNum(unit.intervalHm)} jam'),
          StatBox(
              label: 'Deviasi',
              value: fmtSigned(unit.deviasi),
              valueColor: dueLevelColor(thermoDeviasiLevel(unit.deviasi)),
              sub: unit.due ? 'sudah jatuh tempo' : 'masih aman'),
          StatBox(
              label: 'Lifetime thermostat',
              value: fmtHm(unit.lifetime),
              sub: unit.modifHm == null
                  ? 'belum modif 74°C'
                  : 'sejak modif 74°C'),
        ]),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MiniInfo(
                dotColor: const Color(0xFF175CD3),
                label: 'Last thermostat',
                value: fmtHm(unit.lastHm),
                sub: fmtDateDash(unit.lastDate),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MiniInfo(
                dotColor: unit.modifStatusLabel == 'DONE'
                    ? const Color(0xFF12B76A)
                    : const Color(0xFFF79009),
                label: 'Modif 74°C',
                value: fmtHm(unit.modifHm),
                badge: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    thermoModifBadge(unit.modifStatusLabel),
                    const SizedBox(width: 4),
                    Text(fmtDateDash(unit.modifDate),
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        prokerTable(
          columns: const [
            DataColumn(label: Text('Rencana modif 74°C')),
            DataColumn(label: Text('Radiator check by therma')),
          ],
          rows: [
            DataRow(cells: [
              const DataCell(Text('WR')),
              DataCell(Text(unit.wr ?? '-')),
            ]),
            DataRow(cells: [
              const DataCell(Text('ETA parts')),
              DataCell(Text(fmtDateDash(unit.etaParts))),
            ]),
            DataRow(cells: [
              const DataCell(Text('ETA exec')),
              DataCell(Text(fmtDateDash(unit.etaExec))),
            ]),
            DataRow(cells: [
              const DataCell(Text('Radiator HM • tanggal')),
              DataCell(Text(radHmDate)),
            ]),
            DataRow(cells: [
              const DataCell(Text('Suhu upper / lower')),
              DataCell(Text(suhu)),
            ]),
            DataRow(cells: [
              const DataCell(Text('Radiator remark')),
              DataCell(SizedBox(
                width: 200,
                child: Text(unit.radRemark ?? '-', maxLines: 3),
              )),
            ]),
          ],
        ),
      ],
    );
  }
}
