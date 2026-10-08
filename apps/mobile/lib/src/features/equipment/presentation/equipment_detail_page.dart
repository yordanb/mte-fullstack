import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';

import 'equipment_providers.dart';

/// Detail equipment (EqDetail web): field utama + Komponen/Serial (specs).
class EquipmentDetailPage extends ConsumerWidget {
  final String cn;
  const EquipmentDetailPage({super.key, required this.cn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(eqDetailProvider(cn.toUpperCase()));
    return detailAsync.when(
      data: (r) {
        final main = [
          ('Code Number', r.cn),
          ('Kategori', r.category),
          ('Model', r.unitModel ?? ''),
          ('Unit Type', r.unitType ?? ''),
          ('Product', r.unitProduct ?? ''),
          ('Serial No', r.cnSerialNo ?? ''),
          ('Tahun Unit', r.cnYear != null ? '${r.cnYear}' : ''),
          ('CN Lokasi', r.cnLokasi ?? ''),
          ('Status', r.status ?? ''),
          ('Operasional', r.operasional ?? ''),
          ('Pump Group', r.pumpGroup ?? ''),
          ('Engine', [r.engineModel, r.engineMerk, r.engineSerialNo]
              .where((e) => (e ?? '').isNotEmpty)
              .join(' / ')),
          ('Tgl Datang', r.arrivedCell),
          ('HM Datang', r.arrivedHm != null ? '${r.arrivedHm}' : ''),
          ('Lokasi', r.lokasi ?? ''),
          ('Remark', r.remark ?? ''),
          ('Offhire', r.offhire ?? ''),
          ('Aktif', r.aktif ? 'Ya' : 'Tidak'),
        ];
        final specs = r.specs.entries
            .where((e) => e.value != null && '${e.value}'.isNotEmpty)
            .toList();
        Widget section(String title, List<(String, String)> rows) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                ],
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.$1,
                            style: Theme.of(context).textTheme.bodySmall),
                        Text(row.$2.isEmpty ? '-' : row.$2,
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        const Divider(height: 8),
                      ],
                    ),
                  ),
              ],
            );
        return AppScaffold(
          title: 'Detail ${r.cn}',
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              section('', main),
              if (specs.isNotEmpty)
                section(
                  'Komponen / Serial',
                  [for (final e in specs) (e.key.replaceAll('_', ' '), '${e.value}')],
                ),
            ],
          ),
        );
      },
      loading: () => AppScaffold(
        title: 'Detail $cn',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'Detail $cn',
        body: ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(eqDetailProvider(cn.toUpperCase())),
        ),
      ),
    );
  }
}
