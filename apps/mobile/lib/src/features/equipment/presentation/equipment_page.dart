import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';

import 'equipment_providers.dart';

const _cats = ['BIGWHEEL', 'LIGHTING', 'MOBILE', 'PUMPING'];

/// Kolom list EQ_COLS web + Aktif + Aksi.
const _cols = [
  ('cn', 'Code Number'),
  ('unit_type', 'Unit Type'),
  ('unit_product', 'Product'),
  ('unit_model', 'Model'),
  ('engine', 'Engine'),
];

/// Equipment: cari/filter/sort/tambah/ubah/detail. Meniru EquipmentPage web.
class EquipmentPage extends ConsumerStatefulWidget {
  const EquipmentPage({super.key});

  @override
  ConsumerState<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends ConsumerState<EquipmentPage> {
  late final TextEditingController _q;

  @override
  void initState() {
    super.initState();
    _q = TextEditingController(text: ref.read(eqFilterProvider).q);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(eqFilterProvider);
    final listAsync = ref.watch(eqListProvider);
    final auth = ref.watch(authProvider);

    String arrow(String key) =>
        f.sort == key ? (f.order == 'asc' ? ' ▲' : ' ▼') : '';

    return AppScaffold(
      title: 'Equipment',
      actions: [
        if (auth.can('equipment', 'add'))
          IconButton(
            tooltip: 'Tambah Unit',
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/equipment/new'),
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _q,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Cari CN / type...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: f.cat,
                  hint: const Text('Kategori: semua'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Kategori: semua')),
                    for (final c in _cats) DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) =>
                      ref.read(eqFilterProvider.notifier).apply(cat: v ?? ''),
                ),
                DropdownButton<String>(
                  value: f.aktif,
                  hint: const Text('Status: semua'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Status: semua')),
                    DropdownMenuItem(value: '1', child: Text('Aktif')),
                    DropdownMenuItem(value: '0', child: Text('Nonaktif')),
                  ],
                  onChanged: (v) =>
                      ref.read(eqFilterProvider.notifier).apply(aktif: v ?? ''),
                ),
                FilledButton(
                  onPressed: () => ref
                      .read(eqFilterProvider.notifier)
                      .apply(q: _q.text.trim().toUpperCase()),
                  child: const Text('Tampilkan'),
                ),
              ],
            ),
          ),
          Expanded(
            child: listAsync.when(
              data: (res) {
                final pages = (res.total / eqPageSize).ceil().clamp(1, 1 << 30);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Total ${res.total}'),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(eqListProvider);
                          await ref.read(eqListProvider.future);
                        },
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: [
                                for (final c in _cols)
                                  DataColumn(
                                    label: InkWell(
                                      onTap: () => ref
                                          .read(eqFilterProvider.notifier)
                                          .toggleSort(c.$1),
                                      child: Text('${c.$2}${arrow(c.$1)}'),
                                    ),
                                  ),
                                const DataColumn(label: Text('Aktif')),
                                const DataColumn(label: Text('Aksi')),
                              ],
                              rows: [
                                for (final r in res.rows)
                                  DataRow(
                                    color: r.aktif
                                        ? null
                                        : WidgetStatePropertyAll(
                                            Theme.of(context).disabledColor.withValues(alpha: 0.15),
                                          ),
                                    cells: [
                                      DataCell(Text(r.cn)),
                                      DataCell(Text(r.unitType ?? '')),
                                      DataCell(Text(r.unitProduct ?? '')),
                                      DataCell(Text(r.unitModel ?? '')),
                                      DataCell(Text(r.engineCell)),
                                      DataCell(Text(r.aktif ? 'Ya' : 'Tidak')),
                                      DataCell(Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Lihat detail',
                                            icon: const Icon(Icons.visibility, size: 18),
                                            onPressed: () =>
                                                context.push('/equipment/${r.cn}'),
                                          ),
                                          if (auth.can('equipment', 'edit'))
                                            TextButton(
                                              onPressed: () => context
                                                  .push('/equipment/${r.cn}/edit'),
                                              child: const Text('Ubah'),
                                            ),
                                        ],
                                      )),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (res.rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('Tidak ada data.')),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: res.page <= 1
                                ? null
                                : () => ref
                                    .read(eqFilterProvider.notifier)
                                    .setPage(res.page - 1),
                            child: const Text('‹ Prev'),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Halaman ${res.page} dari $pages'),
                          ),
                          OutlinedButton(
                            onPressed: res.page >= pages
                                ? null
                                : () => ref
                                    .read(eqFilterProvider.notifier)
                                    .setPage(res.page + 1),
                            child: const Text('Next ›'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(eqListProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
