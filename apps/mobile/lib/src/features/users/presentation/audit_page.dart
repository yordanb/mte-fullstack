import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/utils/date_fmt.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';

import 'users_providers.dart';

/// Audit Log (khusus admin): filter tanggal/username/path + tabel +
/// paginasi. Default 7 hari terakhir. Meniru Audit.tsx.
class AuditPage extends ConsumerStatefulWidget {
  const AuditPage({super.key});

  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage> {
  late final TextEditingController _uname;
  late final TextEditingController _path;

  @override
  void initState() {
    super.initState();
    final f = ref.read(auditFilterProvider);
    _uname = TextEditingController(text: f.username);
    _path = TextEditingController(text: f.path);
  }

  @override
  void dispose() {
    _uname.dispose();
    _path.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final f = ref.read(auditFilterProvider);
    final cur = DateTime.tryParse(isFrom ? f.dateFrom : f.dateTo) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    var df = isFrom ? toApiDate(d) : f.dateFrom;
    var dt = isFrom ? f.dateTo : toApiDate(d);
    if (df.compareTo(dt) > 0) {
      if (isFrom) {
        dt = df;
      } else {
        df = dt;
      }
    }
    ref.read(auditFilterProvider.notifier).apply(dateFrom: df, dateTo: dt);
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(auditFilterProvider);
    final auditAsync = ref.watch(auditProvider);

    return AppScaffold(
      title: 'Audit Log',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(fmtDate(f.dateFrom)),
                ),
                const Text('–'),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(fmtDate(f.dateTo)),
                ),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _uname,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _path,
                    decoration: const InputDecoration(
                      labelText: 'Path cth /v1/dbr',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => ref
                      .read(auditFilterProvider.notifier)
                      .apply(username: _uname.text.trim(), path: _path.text.trim()),
                  child: const Text('Tampilkan'),
                ),
              ],
            ),
          ),
          Expanded(
            child: auditAsync.when(
              data: (res) {
                final pages =
                    (res.total / auditPageSize).ceil().clamp(1, 1 << 30);
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
                          ref.invalidate(auditProvider);
                          await ref.read(auditProvider.future);
                        },
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Waktu')),
                                DataColumn(label: Text('User')),
                                DataColumn(label: Text('Role')),
                                DataColumn(label: Text('Method')),
                                DataColumn(label: Text('Path')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('IP')),
                                DataColumn(label: Text('User-Agent')),
                              ],
                              rows: [
                                for (final r in res.rows)
                                  DataRow(cells: [
                                    DataCell(Text(fmtDT(r.createdAt))),
                                    DataCell(Text(r.username ?? '-')),
                                    DataCell(Text(r.role ?? '-')),
                                    DataCell(Text(r.method)),
                                    DataCell(ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 220),
                                      child: Text(r.path,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    )),
                                    DataCell(_StatusBadge(status: r.status)),
                                    DataCell(Text(r.ip ?? '-')),
                                    DataCell(ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 160),
                                      child: Text(r.userAgent ?? '-',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    )),
                                  ]),
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
                                    .read(auditFilterProvider.notifier)
                                    .setPage(res.page - 1),
                            child: const Text('‹ Prev'),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Halaman ${res.page} dari $pages'),
                          ),
                          OutlinedButton(
                            onPressed: res.page >= pages
                                ? null
                                : () => ref
                                    .read(auditFilterProvider.notifier)
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
                onRetry: () => ref.invalidate(auditProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final int status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status >= 200 && status < 300
        ? Colors.green
        : status == 401 || status == 403
            ? Colors.red
            : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$status',
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
