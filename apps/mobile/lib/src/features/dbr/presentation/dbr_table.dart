import 'package:flutter/material.dart';
import 'package:mte_data_center/src/core/utils/date_fmt.dart';

import '../domain/dbr_models.dart';

/// Kolom tampil DBR_COLS web (Pages.tsx:247-254). Dipakai halaman DBR
/// dan dossier FUI.
const dbrTableCols = [
  ('date', 'DATE'),
  ('cn', 'C/N'),
  ('section', 'SECTION'),
  ('trouble', 'Trouble'),
  ('code', 'Code'),
  ('hm_start', 'HM Start'),
  ('loc', 'LOC'),
  ('start_breakdown', 'Start BD'),
  ('action', 'Action'),
  ('mechanic', 'Mechanic'),
  ('gl', 'GL'),
];

String dbrCell(DbrRow r, String key) => switch (key) {
      'date' => fmtDdbr(r.date),
      'cn' => r.cn,
      'section' => r.section ?? '',
      'trouble' => r.trouble ?? '',
      'code' => r.code ?? '',
      'hm_start' => r.hmStart ?? '',
      'loc' => r.loc ?? '',
      'start_breakdown' => r.startBreakdown ?? '',
      'action' => r.action ?? '',
      'mechanic' => r.mechanic ?? '',
      'gl' => r.gl ?? '',
      _ => '',
    };

/// Tabel DBR horizontal. Baris CONTINUE diredupkan agar beda terlihat.
class DbrTable extends StatelessWidget {
  final List<DbrRow> rows;
  const DbrTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: [
              for (final c in dbrTableCols) DataColumn(label: Text(c.$2)),
            ],
            rows: [
              for (final r in rows)
                DataRow(
                  color: r.isContinue
                      ? WidgetStatePropertyAll(
                          Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                        )
                      : null,
                  cells: [
                    for (final c in dbrTableCols) DataCell(Text(dbrCell(r, c.$1))),
                  ],
                ),
            ],
          ),
        ),
      );
}
