import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/utils/date_fmt.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';

import '../domain/mom2_models.dart';
import 'mom2_providers.dart';

/// Halaman MOM 2 — daftar judul meeting weekly SPEX Pumping → klik buka
/// detail item → tombol "← Daftar" (paritas web Mom2.tsx, scope baca).
class Mom2Page extends ConsumerStatefulWidget {
  const Mom2Page({super.key});

  @override
  ConsumerState<Mom2Page> createState() => _Mom2PageState();
}

class _Mom2PageState extends ConsumerState<Mom2Page> {
  int? _selId;

  @override
  Widget build(BuildContext context) {
    if (_selId != null) {
      return _MeetingDetail(
        id: _selId!,
        onBack: () => setState(() => _selId = null),
      );
    }
    return AppScaffold(
      title: 'MOM Weekly SPEX',
      body: _MeetingList(onSelect: (id) => setState(() => _selId = id)),
    );
  }
}

// ─── Daftar meeting ───────────────────────────────────────────────────────

class _MeetingList extends ConsumerWidget {
  final void Function(int id) onSelect;
  const _MeetingList({required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(mom2ListProvider);
    return listAsync.when(
      data: (meetings) {
        if (meetings.isEmpty) {
          return const Center(
            child: Text('Belum ada meeting. Import file MOM weekly lewat web.',
                textAlign: TextAlign.center),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(mom2ListProvider);
            await ref.read(mom2ListProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: meetings.length,
            itemBuilder: (c, i) {
              final m = meetings[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        m.isOpen ? Colors.blue.shade100 : Colors.green.shade100,
                    child: m.isOpen
                        ? Text('${m.openItems}',
                            style: const TextStyle(fontWeight: FontWeight.bold))
                        : const Icon(Icons.check, color: Colors.green),
                  ),
                  title: Text(m.period,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${m.meetingDate == null ? '-' : fmtDate(m.meetingDate)}'
                    '${m.participants != null ? ' • PIC: ${m.participants}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${m.openItems}/${m.totalItems} open\n'
                    '${m.isOpen ? 'Open' : 'Closed'}',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 12,
                      color: m.isOpen ? Colors.blue : Colors.green,
                    ),
                  ),
                  onTap: () => onSelect(m.id),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(mom2ListProvider),
      ),
    );
  }
}

// ─── Detail meeting ───────────────────────────────────────────────────────

class _MeetingDetail extends ConsumerWidget {
  final int id;
  final VoidCallback onBack;
  const _MeetingDetail({required this.id, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(mom2DetailProvider(id));
    return AppScaffold(
      title: 'MOM Weekly SPEX',
      body: detailAsync.when(
        data: (d) {
          final m = d.meeting;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(mom2DetailProvider(id));
              await ref.read(mom2DetailProvider(id).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Daftar'),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(m.period,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium),
                            ),
                            _StatusBadge(status: m.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${m.meetingDate == null ? '-' : fmtDate(m.meetingDate)}'
                          '${m.participants != null ? ' • PIC: ${m.participants}' : ''}'
                          '${m.createdBy != null ? ' • dibuat ${m.createdBy}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Agenda / Temuan (${d.items.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (d.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('Belum ada item meeting.')),
                  )
                else
                  for (final item in d.items) _ItemCard(item: item),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(mom2DetailProvider(id)),
        ),
      ),
    );
  }
}

// ─── Kartu item ───────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final Mom2Item item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final closed = item.status == 'close';
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.seq != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: Text('${item.seq}.',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.topic != null)
                        Text(item.topic!,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 13,
                          decoration:
                              closed ? TextDecoration.lineThrough : null,
                          color: closed ? Colors.grey : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ItemStatusBadge(status: item.status),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (item.reporter != null)
                  Text('Issued: ${item.reporter}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                if (item.pic != null)
                  Text('PIC: ${item.pic}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                if (item.dueDisplay != null)
                  Text('Due: ${fmtDate(item.dueDisplay)}'
                      '${item.dueFlex ? ' (fleksibel)' : ''}',
                      style: TextStyle(
                          fontSize: 11,
                          color: closed ? Colors.grey : Colors.deepOrange)),
                if (item.remark != null)
                  Text('• ${item.remark}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final open = status == 'open';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: open ? Colors.blue.shade100 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        open ? 'Open' : 'Closed',
        style: TextStyle(
          fontSize: 11,
          color: open ? Colors.blue.shade700 : Colors.green.shade700,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ItemStatusBadge extends StatelessWidget {
  final String status;
  const _ItemStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'open' => ('Open', Colors.grey.shade700, Colors.grey.shade100),
      'progress' => ('Progress', Colors.blue.shade700, Colors.blue.shade100),
      'close' => ('Close', Colors.green.shade700, Colors.green.shade100),
      _ => (status, Colors.grey, Colors.grey.shade100),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
