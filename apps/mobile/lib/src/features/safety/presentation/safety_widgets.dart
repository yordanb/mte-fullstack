import 'package:flutter/material.dart';
import 'package:mte_data_center/src/features/safety/data/safety_api.dart';

/// Thumbnail foto Google Drive publik. Hilang bila tanpa id/gagal muat
/// (meniru Thumb web yang return null).
class DriveThumb extends StatelessWidget {
  final String? fileId;
  final String label;
  const DriveThumb({super.key, required this.fileId, required this.label});

  @override
  Widget build(BuildContext context) {
    final fid = (fileId ?? '').trim();
    if (fid.isEmpty || fid == 'null') return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        SafetyApi.driveThumb(fid),
        width: 64,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Badge ✓n / !n hijau-merah (okBadge web).
class OkBadge extends StatelessWidget {
  final bool good;
  final String short;
  final String title;
  const OkBadge({super.key, required this.good, required this.short, required this.title});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: title,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: (good ? Colors.green : Colors.red).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${good ? '✓' : '!'}$short',
            style: TextStyle(
              color: good ? Colors.green.shade700 : Colors.red.shade700,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}

/// Stat kecil gaya web (Section x/y • Respons n).
class StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const StatChip({super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 6),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: valueColor)),
          ],
        ),
      );
}

/// Sel tabel cakupan (redup bila section belum ada data).
class CovCells {
  final bool dim;
  final List<String> cells;
  final bool boldFirst;
  const CovCells(
      {required this.dim, required this.cells, this.boldFirst = false});
}

/// Kartu tabel cakupan per section (dipakai Bomak + R1BI).
class CoverageCard extends StatelessWidget {
  final String title;
  final List<String> headers;
  final List<CovCells> rows;
  const CoverageCard({
    super.key,
    required this.title,
    required this.headers,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: [
                      for (final h in headers)
                        DataColumn(label: Text(h)),
                    ],
                    rows: [
                      for (final r in rows)
                        DataRow(
                          color: r.dim
                              ? WidgetStatePropertyAll(
                                  Theme.of(context)
                                      .disabledColor
                                      .withValues(alpha: 0.15),
                                )
                              : null,
                          cells: [
                            for (var i = 0; i < r.cells.length; i++)
                              DataCell(Text(
                                r.cells[i],
                                style: i == 0 && r.boldFirst
                                    ? const TextStyle(
                                        fontWeight: FontWeight.bold)
                                    : null,
                              )),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// Baris paginasi Prev/Halaman/Next ala web.
class PagerBar extends StatelessWidget {
  final int page;
  final int total;
  final int pageSize;
  final void Function(int page) onPage;
  const PagerBar({
    super.key,
    required this.page,
    required this.total,
    required this.pageSize,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    final pages = (total / pageSize).ceil().clamp(1, 1 << 30);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton(
            onPressed: page <= 1 ? null : () => onPage(page - 1),
            child: const Text('‹ Prev'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('Halaman $page dari $pages'),
          ),
          OutlinedButton(
            onPressed: page >= pages ? null : () => onPage(page + 1),
            child: const Text('Next ›'),
          ),
        ],
      ),
    );
  }
}
