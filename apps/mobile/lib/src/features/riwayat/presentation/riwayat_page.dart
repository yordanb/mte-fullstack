import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_view.dart';
import '../domain/riwayat_models.dart';
import 'riwayat_forms.dart';
import 'riwayat_providers.dart';

/// Hari sejak `startDate` (web daysSince).
int riwayatDaysSince(String? d) {
  if (d == null || d.isEmpty) return 0;
  final start = DateTime.tryParse(d.length >= 10 ? d.substring(0, 10) : d);
  if (start == null) return 0;
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day)
      .difference(DateTime(start.year, start.month, start.day))
      .inDays;
}

/// Daftar issue Riwayat — paritas web Riwayat.tsx (tab + kategori + kartu).
class RiwayatPage extends ConsumerWidget {
  const RiwayatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(riwayatFilterProvider);
    final issuesAsync = ref.watch(riwayatIssuesProvider);

    return AppScaffold(
      title: 'Riwayat',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showIssueForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Issue'),
      ),
      body: Column(
        children: [
          _toolbar(ref, f),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(riwayatIssuesProvider);
                await ref.read(riwayatIssuesProvider.future);
              },
              child: issuesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorView(
                  message: '$e',
                  onRetry: () => ref.invalidate(riwayatIssuesProvider),
                ),
                data: (issues) => issues.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 120),
                        Center(
                            child: Text('Belum ada issue.',
                                style: TextStyle(color: Colors.grey))),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: issues.length,
                        itemBuilder: (_, i) => _issueCard(context, issues[i]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(WidgetRef ref, RiwayatFilter f) {
    final notifier = ref.read(riwayatFilterProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('Semua')),
                  ButtonSegment(value: 'open', label: Text('Open')),
                  ButtonSegment(value: 'closed', label: Text('Closed')),
                ],
                selected: {f.status},
                onSelectionChanged: (s) => notifier.setStatus(s.first),
                style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12))),
              ),
              const Spacer(),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: f.category.isEmpty ? '' : f.category,
                  isDense: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: 'Kategori',
                    labelStyle: TextStyle(fontSize: 11),
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.black),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('semua')),
                    for (final c in riwayatCats)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => notifier.setCategory(v ?? ''),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _issueCard(BuildContext context, RiwayatIssue iss) {
    final dl = riwayatDaysSince(iss.startDate);
    final open = iss.status != 'closed';
    final isVeryOld = open && dl > 30;
    final isOld = open && dl > 7;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isVeryOld
              ? Colors.red.shade300
              : isOld
                  ? Colors.amber.shade300
                  : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/riwayat/${iss.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: open
                    ? Colors.blue.shade50
                    : Colors.green.shade50,
                child: Text(
                  open ? '${dl}d' : '✓',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: open
                          ? Colors.blue.shade600
                          : Colors.green.shade600),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(iss.title,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (iss.cn?.isNotEmpty == true) iss.cn,
                        iss.category,
                        riwayatFmtDate(iss.startDate),
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    if ((iss.lastProgress ?? '').isNotEmpty)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('PROGRESS',
                                style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade600)),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(iss.lastProgress!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade700)),
                          ),
                        ],
                      )
                    else
                      Text('Belum ada progress',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade400)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statusChip(iss.status),
                  if (iss.openParts > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('parts: ${iss.openParts}',
                          style: const TextStyle(
                              fontSize: 10.5, color: Colors.red)),
                    ),
                  if (open && dl > 7)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(dl > 30 ? '>30d!' : '${dl}d',
                          style: TextStyle(
                              fontSize: 10.5,
                              color: dl > 30
                                  ? Colors.red
                                  : Colors.amber.shade700)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'open' => Colors.grey,
      'in_progress' => Colors.blue,
      'waiting_part' => Colors.amber.shade700,
      'waiting_crew' => Colors.purple,
      'closed' => Colors.green,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(riwayatStatusLabel(status),
          style: TextStyle(fontSize: 10.5, color: color)),
    );
  }
}

/// `dd/MM/yyyy` dari `yyyy-MM-dd` (web fmtDate).
String riwayatFmtDate(String? v) {
  if (v == null || v.isEmpty) return '';
  final p = v.split('-');
  if (p.length != 3) return v;
  return '${p[2]}/${p[1]}/${p[0]}';
}
