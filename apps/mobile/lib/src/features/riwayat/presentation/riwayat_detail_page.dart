import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/network/dio_client.dart' show apiMessage;
import '../../../core/widgets/app_scaffold.dart';
import '../data/riwayat_api.dart';
import '../domain/riwayat_models.dart';
import 'riwayat_forms.dart';
import 'riwayat_page.dart' show riwayatFmtDate, riwayatDaysSince;
import 'riwayat_photo_gallery.dart';
import 'riwayat_providers.dart';

/// Detail satu issue: header, ubah status, timeline progress, parts.
class RiwayatDetailPage extends ConsumerWidget {
  final String id;
  const RiwayatDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iid = int.tryParse(id) ?? 0;
    final async = ref.watch(riwayatIssueProvider(iid));
    final auth = ref.watch(authProvider);

    return AppScaffold(
      title: 'Detail Issue',
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: () => ref.invalidate(riwayatIssueProvider(iid)),
                    child: const Text('Coba lagi')),
              ],
            ),
          ),
        ),
        data: (full) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(riwayatIssueProvider(iid));
            await ref.read(riwayatIssueProvider(iid).future);
          },
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _header(context, ref, full, auth),
              const SizedBox(height: 10),
              if (auth.can('riwayat', 'edit')) _statusChanger(context, ref, full),
              const SizedBox(height: 10),
              _progressSection(context, ref, full, auth),
              const SizedBox(height: 10),
              _partsSection(context, ref, full, auth),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, RiwayatIssueFull full,
      AuthState auth) {
    final iss = full.issue;
    final dl = riwayatDaysSince(iss.startDate);
    final isOld = iss.status != 'closed' && dl > 7;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: isOld ? Colors.amber.shade300 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const BackButton(),
                const Spacer(),
                if (auth.can('riwayat', 'edit'))
                  TextButton(
                    onPressed: () => showIssueForm(context, ref, issue: iss),
                    child: const Text('Ubah'),
                  ),
                if (auth.isAdmin)
                  IconButton(
                    tooltip: 'Hapus',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteIssue(context, ref, iss),
                  ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(iss.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (iss.cn?.isNotEmpty == true) iss.cn,
                iss.category,
                riwayatFmtDate(iss.startDate),
                if (iss.endDate?.isNotEmpty == true) '→ ${riwayatFmtDate(iss.endDate)}',
                if (iss.createdBy?.isNotEmpty == true) 'oleh ${iss.createdBy}',
              ].join(' • '),
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
            if ((iss.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(iss.description!, style: const TextStyle(fontSize: 12.5)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _statusChip(iss.status),
                const Spacer(),
                if (isOld)
                  Text(
                    '⚠ Open $dl hari (${dl > 30 ? '>30 hari!' : '>7 hari'})',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.amber.shade700),
                  ),
              ],
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(riwayatStatusLabel(status),
          style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Widget _statusChanger(
      BuildContext context, WidgetRef ref, RiwayatIssueFull full) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Ubah status:',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        for (final s in riwayatStatuses)
          ChoiceChip(
            label: Text(s.label, style: const TextStyle(fontSize: 11)),
            selected: s.value == full.issue.status,
            onSelected: (_) => _cycleStatus(context, ref, full.issue, s.value),
          ),
      ],
    );
  }

  Widget _progressSection(BuildContext context, WidgetRef ref,
      RiwayatIssueFull full, AuthState auth) {
    final canAdd = auth.can('riwayat', 'add');
    final canEdit = auth.can('riwayat', 'edit');
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Text('Progress Timeline (${full.progress.length})',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (canAdd && full.issue.status != 'closed')
                  TextButton.icon(
                    onPressed: () =>
                        showProgressForm(context, ref, full.issue.id),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Progress',
                        style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          if (full.progress.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text('Belum ada progress.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            )
          else
            for (var i = 0; i < full.progress.length; i++)
              _progressTile(context, ref, full.progress[i], i + 1, canEdit,
                  auth.isAdmin),
        ],
      ),
    );
  }

  Widget _progressTile(BuildContext context, WidgetRef ref,
      RiwayatProgress pr, int seq, bool canEdit, bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text('$seq',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pr.description, style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      [
                        riwayatFmtDate(pr.logDate),
                        if (pr.createdBy?.isNotEmpty == true) pr.createdBy,
                      ].join(' • '),
                      style:
                          TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                    ),
                    if (pr.partRequired) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('⚠ Part Required',
                            style: TextStyle(
                                fontSize: 9.5, color: Colors.amber.shade800)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                RiwayatPhotoGallery(
                  kind: 'progress',
                  itemId: pr.id,
                  load: () =>
                      ref.read(riwayatApiProvider).progressPhotos(pr.id),
                  upload: (paths, names) => ref
                      .read(riwayatApiProvider)
                      .addProgressPhotos(pr.id, paths, names),
                  delete: (phid) => ref
                      .read(riwayatApiProvider)
                      .deleteProgressPhoto(pr.id, phid),
                  patchNotes: (phid, notes) => ref
                      .read(riwayatApiProvider)
                      .patchProgressPhotoNotes(pr.id, phid, notes),
                ),
                if (pr.partRequired) _progressParts(context, ref, pr.id),
              ],
            ),
          ),
          if (canEdit || isAdmin)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  size: 18, color: Colors.grey.shade500),
              onSelected: (v) {
                if (v == 'edit') {
                  showProgressForm(context, ref, pr.issueId, progress: pr);
                } else if (v == 'delete') {
                  _deleteProgress(context, ref, pr);
                }
              },
              itemBuilder: (_) => [
                if (canEdit)
                  const PopupMenuItem(value: 'edit', child: Text('Ubah')),
                if (isAdmin)
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Hapus', style: TextStyle(color: Colors.red))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _progressParts(BuildContext context, WidgetRef ref, int pid) {
    final partsAsync = ref.watch(riwayatPartsByProgressProvider(pid));
    final parts = partsAsync.maybeWhen(data: (v) => v, orElse: () => const <RiwayatPart>[]);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🔧 Part Request',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade800)),
              const SizedBox(width: 6),
              Text('(${parts.length})',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
              const Spacer(),
              TextButton(
                onPressed: () => showPartForm(context, ref, progressId: pid),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 28)),
                child: const Text('+ Part', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          for (final p in parts)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${p.partName} ×${p.qty}',
                        style: const TextStyle(fontSize: 11.5)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Text(riwayatPartStatusLabel(p.status),
                        style: const TextStyle(fontSize: 9.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _partsSection(BuildContext context, WidgetRef ref,
      RiwayatIssueFull full, AuthState auth) {
    final canAdd = auth.can('riwayat', 'add');
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Text('Parts Requirement (${full.parts.length})',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (canAdd && full.issue.status != 'closed')
                  full.progress.isEmpty
                      ? Text('Buat progress dulu',
                          style: TextStyle(
                              fontSize: 10.5, color: Colors.grey.shade500))
                      : TextButton.icon(
                          onPressed: () =>
                              showPartForm(context, ref, issueId: full.issue.id),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Part',
                              style: TextStyle(fontSize: 12)),
                        ),
              ],
            ),
          ),
          if (full.parts.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text('Belum ada part.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            )
          else
            for (final pt in full.parts) _partTile(context, ref, pt, auth),
        ],
      ),
    );
  }

  Widget _partTile(
      BuildContext context, WidgetRef ref, RiwayatPart pt, AuthState auth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: pt.partName,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w500)),
                  TextSpan(
                      text: '  (qty: ${pt.qty})',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ])),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(riwayatPartStatusLabel(pt.status),
                          style: const TextStyle(fontSize: 10)),
                    ),
                    if (pt.createdAt?.isNotEmpty == true)
                      Text('Dibuat: ${riwayatFmtDate(pt.createdAt)}',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade400)),
                    if (pt.eta?.isNotEmpty == true)
                      Text('ETA: ${riwayatFmtDate(pt.eta)}',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
                RiwayatPhotoGallery(
                  kind: 'part',
                  itemId: pt.id,
                  load: () => ref.read(riwayatApiProvider).partPhotos(pt.id),
                  upload: (paths, names) => ref
                      .read(riwayatApiProvider)
                      .addPartPhotos(pt.id, paths, names),
                  delete: (phid) => ref
                      .read(riwayatApiProvider)
                      .deletePartPhoto(pt.id, phid),
                  patchNotes: (phid, notes) => ref
                      .read(riwayatApiProvider)
                      .patchPartPhotoNotes(pt.id, phid, notes),
                ),
              ],
            ),
          ),
          if (auth.can('riwayat', 'edit') || auth.isAdmin)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  size: 18, color: Colors.grey.shade500),
              onSelected: (v) {
                if (v == 'edit') {
                  showPartForm(context, ref,
                      issueId: pt.issueId, part: pt);
                } else if (v == 'delete') {
                  _deletePart(context, ref, pt);
                }
              },
              itemBuilder: (_) => [
                if (auth.can('riwayat', 'edit'))
                  const PopupMenuItem(value: 'edit', child: Text('Ubah')),
                if (auth.isAdmin)
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Hapus', style: TextStyle(color: Colors.red))),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _cycleStatus(BuildContext context, WidgetRef ref,
      RiwayatIssue iss, String next) async {
    try {
      await ref.read(riwayatApiProvider).patchIssue(iss.id, {'status': next});
      ref.invalidate(riwayatIssueProvider(iss.id));
      ref.invalidate(riwayatIssuesProvider);
    } catch (e) {
      if (context.mounted) _snack(context, apiMessage(e));
    }
  }

  Future<void> _deleteIssue(
      BuildContext context, WidgetRef ref, RiwayatIssue iss) async {
    final ok = await _confirm(context,
        'Hapus issue "${iss.title}"?\nSemua progress dan parts akan terhapus.');
    if (ok != true) return;
    try {
      await ref.read(riwayatApiProvider).deleteIssue(iss.id);
      ref.invalidate(riwayatIssuesProvider);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) _snack(context, apiMessage(e));
    }
  }

  Future<void> _deleteProgress(
      BuildContext context, WidgetRef ref, RiwayatProgress pr) async {
    final ok = await _confirm(context, 'Hapus progress ini?');
    if (ok != true) return;
    try {
      await ref.read(riwayatApiProvider).deleteProgress(pr.id);
      ref.invalidate(riwayatIssueProvider(pr.issueId));
    } catch (e) {
      if (context.mounted) _snack(context, apiMessage(e));
    }
  }

  Future<void> _deletePart(
      BuildContext context, WidgetRef ref, RiwayatPart pt) async {
    final ok = await _confirm(context, 'Hapus part ini?');
    if (ok != true) return;
    try {
      await ref.read(riwayatApiProvider).deletePart(pt.id);
      ref.invalidate(riwayatIssueProvider(pt.issueId));
    } catch (e) {
      if (context.mounted) _snack(context, apiMessage(e));
    }
  }
}

Future<bool?> _confirm(BuildContext context, String message) => showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hapus')),
        ],
      ),
    );

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
