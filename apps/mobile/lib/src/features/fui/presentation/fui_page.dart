import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';
import 'package:mte_data_center/src/features/dbr/presentation/dbr_table.dart';
import 'package:mte_data_center/src/features/equipment/presentation/equipment_providers.dart';

import 'fui_providers.dart';
import 'oil_table.dart';

/// FUI dossier per CN: info equipment + 10 DBR USM + 10 oil per component.
/// Export PDF disembunyikan (hasil belum sesuai, handoff §5). Meniru FuiPage.
class FuiPage extends ConsumerStatefulWidget {
  const FuiPage({super.key});

  @override
  ConsumerState<FuiPage> createState() => _FuiPageState();
}

class _FuiPageState extends ConsumerState<FuiPage> {
  late final TextEditingController _cn;

  @override
  void initState() {
    super.initState();
    _cn = TextEditingController();
  }

  @override
  void dispose() {
    _cn.dispose();
    super.dispose();
  }

  void _load() {
    final v = _cn.text.trim().toUpperCase();
    if (v.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi code number dulu.')),
      );
      return;
    }
    _cn.text = v;
    ref.read(dossierCnProvider.notifier).open(v);
  }

  @override
  Widget build(BuildContext context) {
    final cn = ref.watch(dossierCnProvider);
    final eqAsync = cn.isEmpty
        ? null
        : ref.watch(eqDetailProvider(cn));
    final dbrAsync = ref.watch(dossierDbrProvider);
    final oilsAsync = ref.watch(dossierOilsProvider);

    return AppScaffold(
      title: 'FUI',
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('FUI — Follow Up Instruction'),
          Text(
            'Dossier per unit: info equipment + 10 DBR terbaru + 10 oil terakhir per component',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cn,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _load(),
                  decoration: const InputDecoration(
                    labelText: 'Code number cth WP855',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _load, child: const Text('Tampilkan')),
            ],
          ),
          const SizedBox(height: 12),
          if (cn.isNotEmpty && eqAsync != null)
            eqAsync.when(
              data: (e) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      for (final kv in [
                        ('Code Unit', e.cn),
                        ('Unit Type', e.unitType ?? '-'),
                        ('Product', e.unitProduct ?? '-'),
                        ('Engine', e.engineCell.isEmpty ? '-' : e.engineCell),
                        ('CN Serial No', e.cnSerialNo ?? '-'),
                        ('Engine Serial No', e.engineSerialNo ?? '-'),
                      ])
                        SizedBox(
                          width: 150,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(kv.$1,
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                              Text(kv.$2,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                  ],
                ),
              )),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) {
                // 404 = CN tidak ada di master: DBR & oil tetap ditampilkan.
                if (e.toString().contains('tidak ditemukan')) {
                  return Card(
                    color: Colors.yellow.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                          'Tidak ada di master Equipment — DBR & oil tetap ditampilkan.'),
                    ),
                  );
                }
                return ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(eqDetailProvider(cn)),
                );
              },
            ),
          if (cn.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('10 DBR Breakdown terbaru (Code USM, tanpa CONTINUE) — $cn',
                style: Theme.of(context).textTheme.titleSmall),
            dbrAsync.when(
              data: (rows) => rows.isEmpty
                  ? Text('Tidak ada data DBR untuk $cn.',
                      style: Theme.of(context).textTheme.bodySmall)
                  : Card(child: DbrTable(rows: rows)),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(dossierDbrProvider),
              ),
            ),
            oilsAsync.when(
              data: (units) {
                final dbrEmpty = switch (dbrAsync) {
                  AsyncData(:final value) => value.isEmpty,
                  _ => true,
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final u in units) ...[
                      const SizedBox(height: 12),
                      Text('Component: ${u.unit} — 10 oil terakhir',
                          style: Theme.of(context).textTheme.titleSmall),
                      Card(child: OilTable(rows: u.rows)),
                    ],
                    if (units.isEmpty && !dbrEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Tidak ada data oil untuk $cn.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(dossierOilsProvider),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
