import 'package:flutter/material.dart';
import 'package:mte_data_center/src/core/utils/date_fmt.dart';
import 'package:mte_data_center/src/core/utils/unit_short.dart';

import '../domain/fui_models.dart';

/// Tabel oil ringkas (VesselTable web disederhanakan jadi 1 baris header):
/// Lab, Sampl/Analisys, SAE, HM, parameter + Condition. Sel merah bila
/// grade bukan N. Tombol Suggest pada baris non-NORMAL bila onSuggest diisi.
class OilTable extends StatelessWidget {
  final List<OilRow> rows;
  final bool showVessel;
  final void Function(OilRow row)? onSuggest;
  const OilTable({super.key, required this.rows, this.showVessel = true, this.onSuggest});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            if (showVessel) const DataColumn(label: Text('Vessel Id')),
            const DataColumn(label: Text('Unit Id')),
            const DataColumn(label: Text('Lab No.')),
            const DataColumn(label: Text('Sampl Date')),
            const DataColumn(label: Text('SAE')),
            const DataColumn(label: Text('HM')),
            for (final l in OilRow.paramLabels) DataColumn(label: Text(l)),
            const DataColumn(label: Text('Condition')),
          ],
          rows: [
            for (final r in rows)
              DataRow(cells: [
                if (showVessel) DataCell(Text(r.vesselId)),
                DataCell(Text(shortUnit(r.unitId))),
                DataCell(Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.labNo),
                    Text(r.leadTime ?? '', style: Theme.of(context).textTheme.bodySmall),
                  ],
                )),
                DataCell(Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fmtDate(r.sampleDate)),
                    Text(fmtDate(r.dateTaken),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                )),
                DataCell(Text(r.oilWeight ?? '')),
                DataCell(Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.unitTime ?? ''),
                    Text(r.unitTimeOils ?? '',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                )),
                for (var i = 0; i < OilRow.params.length; i++)
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      color: r.badGrade(OilRow.params[i])
                          ? Colors.red.withValues(alpha: 0.15)
                          : null,
                      child: Text(
                        r.vals[OilRow.params[i]] ?? '',
                        style: r.badGrade(OilRow.params[i])
                            ? const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold)
                            : null,
                      ),
                    ),
                  ),
                DataCell(Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (r.condition == 'NORMAL'
                                ? Colors.green
                                : Colors.red)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        r.condition ?? '-',
                        style: TextStyle(
                          color: r.condition == 'NORMAL' ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (onSuggest != null && r.condition != 'NORMAL')
                      TextButton(
                        onPressed: () => onSuggest!(r),
                        child: const Text('Suggest',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ],
                )),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Badge kecil Sudah(n)/Belum untuk kolom Suggest report.
class SuggestBadge extends StatelessWidget {
  final int count;
  const SuggestBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final done = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (done ? Colors.green : Colors.grey).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        done ? 'Sudah ($count)' : 'Belum',
        style: TextStyle(
          color: done ? Colors.green : Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
