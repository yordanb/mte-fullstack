import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'dashboard_providers.dart';
import '../../../core/utils/date_fmt.dart';
import '../../../core/utils/unit_short.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';

/// Dashboard oli Milestone 1: latest per unit + cari vessel + filter
/// Critical TL/GS/WP + last update. Meniru Pages.tsx Dashboard web.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dashboardFilterProvider);
    final rowsAsync = ref.watch(dashboardRowsProvider);
    final lastUpAsync = ref.watch(lastImportProvider);

    return AppScaffold(
      title: 'Dashboard Oli',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardRowsProvider);
          ref.invalidate(lastImportProvider);
          await ref.read(dashboardRowsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _SearchBar(filter: filter, ref: ref),
            const SizedBox(height: 8),
            _CriticalRadios(filter: filter, ref: ref),
            const SizedBox(height: 8),
            lastUpAsync.when(
              data: (last) => last == null
                  ? const SizedBox.shrink()
                  : Text(
                      'Last update: ${last.filename} • ${fmtDT(last.createdAt)} • '
                      '${last.status} • ok ${last.okRows}/${last.totalRows}'
                      '${(last.uploadedBy?.isNotEmpty ?? false) ? ' oleh ${last.uploadedBy}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            rowsAsync.when(
              data: (res) {
                if (res.error != null) {
                  return ErrorView(
                    message: res.error!,
                    onRetry: () => ref.invalidate(dashboardRowsProvider),
                  );
                }
                // Web: crit = condition !== 'NORMAL' (WARNING ikut).
                final crit = res.rows.where((r) => (r.condition ?? '') != 'NORMAL').length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 16,
                      children: [
                        Text('Total ${res.rows.length}'),
                        Text('CRITICAL $crit',
                            style: TextStyle(
                                color: crit > 0 ? Colors.red : null,
                                fontWeight: FontWeight.bold)),
                        Text('NORMAL ${res.rows.length - crit}',
                            style: const TextStyle(color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (res.rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('Tidak ada data')),
                      )
                    else
                      ...res.rows.map((r) => _RowCard(
                            vessel: r.vesselId,
                            unit: shortUnit(r.unitId),
                            rawUnit: r.unitId,
                            labNo: r.labNo,
                            sample: fmtDate(r.sampleDate),
                            taken: fmtDate(r.dateTaken),
                            condition: r.condition ?? '-',
                          )),
                  ],
                );
              },
              loading: () => _LoadingShimmer(),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(dashboardRowsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final DashboardFilter filter;
  final WidgetRef ref;
  const _SearchBar({required this.filter, required this.ref});

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(dashboardFilterProvider.notifier);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: ValueKey('vessel-${filter.mode}-${filter.critPrefix}'),
                decoration: const InputDecoration(
                  labelText: 'Vessel (kosong=semua)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: notifier.setVessel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: ValueKey('unit-${filter.mode}-${filter.critPrefix}'),
                decoration: const InputDecoration(
                  labelText: 'Unit (opsional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: notifier.setUnit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: notifier.applySearch,
                child: const Text('Cari 20 terbaru'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {
                notifier.reset();
                ref.invalidate(dashboardRowsProvider);
              },
              child: const Text('Reset'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CriticalRadios extends StatelessWidget {
  final DashboardFilter filter;
  final WidgetRef ref;
  const _CriticalRadios({required this.filter, required this.ref});

  @override
  Widget build(BuildContext context) {
    const prefixes = ['TL', 'GS', 'WP'];
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Critical:'),
        for (final p in prefixes)
          ChoiceChip(
            label: Text(p),
            selected: filter.critPrefix == p,
            onSelected: (_) {
              ref.read(dashboardFilterProvider.notifier).applyCritical(p);
              ref.invalidate(dashboardRowsProvider);
            },
          ),
      ],
    );
  }
}

class _RowCard extends StatelessWidget {
  final String vessel;
  final String unit;
  final String rawUnit;
  final String labNo;
  final String sample;
  final String taken;
  final String condition;

  const _RowCard({
    required this.vessel,
    required this.unit,
    required this.rawUnit,
    required this.labNo,
    required this.sample,
    required this.taken,
    required this.condition,
  });

  @override
  Widget build(BuildContext context) {
    final isNormal = condition == 'NORMAL';
    return Card(
      child: ListTile(
        title: Text('$vessel • $unit'),
        subtitle: Text('$labNo\nSampl $sample • Analisys $taken'),
        isThreeLine: true,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isNormal ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            condition,
            style: TextStyle(
              color: isNormal ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        highlightColor: Theme.of(context).colorScheme.surface,
        child: Column(
          children: List.generate(
            6,
            (_) => Container(
              height: 72,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      );
}
