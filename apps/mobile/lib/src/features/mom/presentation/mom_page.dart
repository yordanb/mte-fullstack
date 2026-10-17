import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;
import 'package:mte_data_center/src/core/utils/date_fmt.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';

import '../data/mom_api.dart';
import '../domain/mom_models.dart';
import 'mom_providers.dart';

/// Halaman Minute of Meeting: list meeting → detail + action items.
/// Meniru web Mom.tsx: filter Open/Closed, kategori, checkbox toggle item.
class MomPage extends ConsumerStatefulWidget {
  const MomPage({super.key});

  @override
  ConsumerState<MomPage> createState() => _MomPageState();
}

class _MomPageState extends ConsumerState<MomPage> {
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
      title: 'Minute of Meeting',
      actions: [
        if (ref.watch(authProvider).can('mom', 'add'))
          IconButton(
            tooltip: 'Meeting baru',
            icon: const Icon(Icons.add),
            onPressed: () => _showMeetingForm(context),
          ),
      ],
      body: _MeetingList(onSelect: (id) => setState(() => _selId = id)),
    );
  }

  void _showMeetingForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _MeetingForm(),
    ).then((saved) {
      if (saved == true) invalidateMom(ref);
    });
  }
}

// ─── Meeting List ──────────────────────────────────────────

class _MeetingList extends ConsumerWidget {
  final void Function(int id) onSelect;
  const _MeetingList({required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(momFilterProvider);
    final listAsync = ref.watch(momListProvider);
    final notifier = ref.read(momFilterProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('Semua')),
                  ButtonSegment(value: 'open', label: Text('Open')),
                  ButtonSegment(value: 'closed', label: Text('Closed')),
                ],
                selected: {filter.status},
                onSelectionChanged: (s) => notifier.setStatus(s.first),
              ),
              DropdownButton<String>(
                value: filter.category.isEmpty ? '' : filter.category,
                hint: const Text('Kategori: semua'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Kategori: semua')),
                  for (final c in momCats) DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => notifier.setCategory(v ?? ''),
              ),
            ],
          ),
        ),
        Expanded(
          child: listAsync.when(
            data: (meetings) {
              if (meetings.isEmpty) {
                return const Center(child: Text('Belum ada meeting.'));
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(momListProvider);
                  await ref.read(momListProvider.future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: meetings.length,
                  itemBuilder: (c, i) {
                    final m = meetings[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: m.status == 'open'
                              ? Colors.blue.shade100
                              : Colors.green.shade100,
                          child: m.status == 'open'
                              ? Text('${m.openItems}',
                                  style: const TextStyle(fontWeight: FontWeight.bold))
                              : const Icon(Icons.check, color: Colors.green),
                        ),
                        title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${fmtDate(m.meetingDate)} • ${m.category}'
                          '${m.location != null ? ' • ${m.location}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          '${m.openItems}/${m.totalItems}\n${m.status == 'open' ? 'Open' : 'Closed'}',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            color: m.status == 'open' ? Colors.blue : Colors.green,
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
              onRetry: () => ref.invalidate(momListProvider),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Meeting Detail ────────────────────────────────────────

class _MeetingDetail extends ConsumerWidget {
  final int id;
  final VoidCallback onBack;
  const _MeetingDetail({required this.id, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(momDetailProvider(id));
    final canEdit = ref.watch(authProvider).can('mom', 'edit');
    final canAdd = ref.watch(authProvider).can('mom', 'add');
    final canDel = ref.watch(authProvider).can('mom', 'delete');

    return AppScaffold(
      title: 'Meeting',
      actions: [
        if (canEdit)
          IconButton(
            tooltip: 'Ubah',
            icon: const Icon(Icons.edit),
            onPressed: () {
              final d = ref.read(momDetailProvider(id)).valueOrNull;
              if (d != null) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _MeetingForm(meeting: d.meeting),
                ).then((saved) {
                  if (saved == true) ref.invalidate(momDetailProvider(id));
                });
              }
            },
          ),
      ],
      body: detailAsync.when(
        data: (d) {
          final m = d.meeting;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(momDetailProvider(id));
              await ref.read(momDetailProvider(id).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Back + toggle status
                Row(
                  children: [
                    OutlinedButton(onPressed: onBack, child: const Text('‹ Kembali')),
                    const Spacer(),
                    if (canEdit)
                      FilledButton.tonal(
                        onPressed: () async {
                          final next = m.status == 'open' ? 'closed' : 'open';
                          try {
                            await ref.read(momApiProvider).patchMeeting(id, {'status': next});
                            ref.invalidate(momDetailProvider(id));
                            invalidateMom(ref);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(apiMessage(e))));
                            }
                          }
                        },
                        child: Text(m.status == 'open' ? 'Tutup Meeting' : 'Buka Kembali'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Meeting header card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(m.title,
                                  style: Theme.of(context).textTheme.titleMedium),
                            ),
                            _StatusBadge(status: m.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${fmtDate(m.meetingDate)} • ${m.category}'
                          '${m.location != null ? ' • ${m.location}' : ''}'
                          '${m.createdBy != null ? ' • oleh ${m.createdBy}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Action items header
                Row(
                  children: [
                    Text('Action Items (${d.items.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (canAdd && m.status == 'open')
                      TextButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => _ItemForm(meetingId: id),
                          ).then((saved) {
                            if (saved == true) ref.invalidate(momDetailProvider(id));
                          });
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Item'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                // Items list
                if (d.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('Belum ada action item.')),
                  )
                else
                  for (final item in d.items)
                    _ItemCard(
                      item: item,
                      canEdit: canEdit,
                      canDel: canDel,
                      onToggle: () async {
                        try {
                          final next = item.status == 'closed' ? 'open' : 'closed';
                          await ref.read(momApiProvider).patchItem(item.id, {'status': next});
                          ref.invalidate(momDetailProvider(id));
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(apiMessage(e))));
                          }
                        }
                      },
                      onEdit: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => _ItemForm(meetingId: id, item: item),
                        ).then((saved) {
                          if (saved == true) ref.invalidate(momDetailProvider(id));
                        });
                      },
                      onDelete: canDel
                          ? () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Hapus item?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
                                  ],
                                ),
                              );
                              if (ok != true) return;
                              try {
                                await ref.read(momApiProvider).deleteItem(item.id);
                                ref.invalidate(momDetailProvider(id));
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(content: Text(apiMessage(e))));
                                }
                              }
                            }
                          : null,
                    ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(momDetailProvider(id)),
        ),
      ),
    );
  }
}

// ─── Item Card ─────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final MomItem item;
  final bool canEdit;
  final bool canDel;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _ItemCard({
    required this.item,
    required this.canEdit,
    required this.canDel,
    required this.onToggle,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final closed = item.status == 'closed';
    final dl = _daysLeft(item.dueDate);
    final overdue = dl != null && dl < 0 && !closed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox toggle
            InkWell(
              onTap: canEdit ? onToggle : null,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  closed ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20,
                  color: closed ? Colors.green : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description,
                    style: TextStyle(
                      decoration: closed ? TextDecoration.lineThrough : null,
                      color: closed ? Colors.grey : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _PriorityBadge(priority: item.priority),
                      _ItemStatusBadge(status: item.status),
                      if (item.pic != null)
                        Text('PIC: ${item.pic}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      if (item.dueDate != null)
                        Text(
                          'Due: ${fmtDate(item.dueDate)}'
                          '${!closed && dl != null ? ' (${dl > 0 ? '${dl}d' : 'overdue'})' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: overdue ? Colors.red : Colors.grey,
                            fontWeight: overdue ? FontWeight.bold : null,
                          ),
                        ),
                      if (item.notes != null)
                        Text('• ${item.notes}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            if (canEdit)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete' && onDelete != null) onDelete!();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Ubah')),
                  if (canDel) const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

int? _daysLeft(String? due) {
  if (due == null || due.isEmpty) return null;
  final d = DateTime.tryParse(due.length >= 10 ? due.substring(0, 10) : due);
  if (d == null) return null;
  final today = DateTime.now();
  return d.difference(DateTime(today.year, today.month, today.day)).inDays;
}

// ─── Badges ────────────────────────────────────────────────

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

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (priority) {
      'high' => (Colors.red.shade700, Colors.red.shade100),
      'low' => (Colors.blue.shade700, Colors.blue.shade100),
      _ => (Colors.amber.shade800, Colors.amber.shade100),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(priority, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
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
      'in_progress' => ('In Progress', Colors.blue.shade700, Colors.blue.shade100),
      'closed' => ('Closed', Colors.green.shade700, Colors.green.shade100),
      _ => (status, Colors.grey, Colors.grey.shade100),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Meeting Form ──────────────────────────────────────────

class _MeetingForm extends ConsumerStatefulWidget {
  final MomMeeting? meeting;
  const _MeetingForm({this.meeting});

  @override
  ConsumerState<_MeetingForm> createState() => _MeetingFormState();
}

class _MeetingFormState extends ConsumerState<_MeetingForm> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late String _date;
  late String _category;
  String? _msg;
  bool _busy = false;

  bool get _isEdit => widget.meeting != null;

  @override
  void initState() {
    super.initState();
    final m = widget.meeting;
    _title = TextEditingController(text: m?.title ?? '');
    _location = TextEditingController(text: m?.location ?? '');
    _date = (m?.meetingDate ?? toApiDate(DateTime.now()));
    _category = m?.category ?? 'Operasional';
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final cur = DateTime.tryParse(_date) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = toApiDate(d));
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _msg = 'Judul wajib diisi');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final api = ref.read(momApiProvider);
      if (_isEdit) {
        await api.patchMeeting(widget.meeting!.id, {
          'title': _title.text.trim(),
          'meeting_date': _date,
          'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
          'category': _category,
        });
      } else {
        await api.createMeeting(
          title: _title.text.trim(),
          meetingDate: _date,
          location: _location.text.trim().isEmpty ? null : _location.text.trim(),
          category: _category,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => _msg = apiMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Ubah Meeting' : 'Meeting Baru',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Judul',
                hintText: 'cth Daily Meeting Pumping',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tanggal',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(fmtDate(_date)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final c in momCats) DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? 'Operasional'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Lokasi',
                hintText: 'cth Ruang Meeting SSE',
                border: OutlineInputBorder(),
              ),
            ),
            if (_msg != null) ...[
              const SizedBox(height: 8),
              Text(_msg!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Batal')),
                const SizedBox(width: 8),
                FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? '...' : 'Simpan')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Item Form ─────────────────────────────────────────────

class _ItemForm extends ConsumerStatefulWidget {
  final int meetingId;
  final MomItem? item;
  const _ItemForm({required this.meetingId, this.item});

  @override
  ConsumerState<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends ConsumerState<_ItemForm> {
  late final TextEditingController _desc;
  late final TextEditingController _pic;
  late final TextEditingController _notes;
  late String? _due;
  late String _priority;
  late String _status;
  String? _msg;
  bool _busy = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _desc = TextEditingController(text: i?.description ?? '');
    _pic = TextEditingController(text: i?.pic ?? '');
    _notes = TextEditingController(text: i?.notes ?? '');
    _due = i?.dueDate;
    _priority = i?.priority ?? 'medium';
    _status = i?.status ?? 'open';
  }

  @override
  void dispose() {
    _desc.dispose();
    _pic.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final cur = _due != null ? DateTime.tryParse(_due!) : null;
    final d = await showDatePicker(
      context: context,
      initialDate: cur ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _due = toApiDate(d));
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_desc.text.trim().isEmpty) {
      setState(() => _msg = 'Deskripsi wajib diisi');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final api = ref.read(momApiProvider);
      if (_isEdit) {
        await api.patchItem(widget.item!.id, {
          'description': _desc.text.trim(),
          'pic': _pic.text.trim().isEmpty ? null : _pic.text.trim(),
          'due_date': _due,
          'priority': _priority,
          'status': _status,
          'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        });
      } else {
        await api.addItem(
          widget.meetingId,
          description: _desc.text.trim(),
          pic: _pic.text.trim().isEmpty ? null : _pic.text.trim(),
          dueDate: _due,
          priority: _priority,
          status: _status,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _msg = apiMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Ubah Item' : 'Action Item Baru',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Deskripsi',
                hintText: 'cth Cek pompa WP855 flow rendah',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pic,
                    decoration: const InputDecoration(
                      labelText: 'PIC',
                      hintText: 'cth Budi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _pickDue,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Due Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_due != null ? fmtDate(_due!) : '-'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final p in momPriorities)
                        DropdownMenuItem(value: p, child: Text(p)),
                    ],
                    onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final s in momItemStatuses)
                        DropdownMenuItem(value: s, child: Text(s)),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? 'open'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            if (_msg != null) ...[
              const SizedBox(height: 8),
              Text(_msg!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Batal')),
                const SizedBox(width: 8),
                FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? '...' : 'Simpan')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
