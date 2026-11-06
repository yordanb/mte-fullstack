import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/network/dio_client.dart' show apiMessage;
import '../data/project_api.dart';
import '../domain/project_models.dart';
import 'project_forms.dart';
import 'project_providers.dart';
import 'project_widgets.dart';

/// Panel detail project (bottom sheet) — paritas web ProjectDetail.
Future<void> showProjectDetail(
    BuildContext context, WidgetRef ref, String id) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (c, scroll) => _ProjectDetailBody(id: id, scroll: scroll),
    ),
  );
}

class _ProjectDetailBody extends ConsumerWidget {
  final String id;
  final ScrollController scroll;
  const _ProjectDetailBody({required this.id, required this.scroll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectDetailProvider(id));
    final auth = ref.watch(authProvider);
    final canWrite = auth.can('project', 'edit') || auth.can('project', 'add');

    return async.when(
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
                onPressed: () => ref.invalidate(projectDetailProvider(id)),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      ),
      data: (p) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            [
              p.cn,
              p.crew,
              if ((p.pic ?? '').isNotEmpty) 'PIC ${p.pic}',
              if ((p.targetDate ?? '').isNotEmpty)
                'Target ${projFmtD(p.targetDate)}',
            ].where((e) => e != null && e.isNotEmpty).join(' • '),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          if ((p.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(p.description!, style: const TextStyle(fontSize: 12.5)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (p.progress.clamp(0, 100)) / 100,
                    minHeight: 9,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${p.progress}%',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              ProjBadge(status: p.derived),
            ],
          ),
          if (canWrite) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showStageForm(context, ref, p.id),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Tahap'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        content: Text(
                            'Hapus project "${p.name}" beserta semua tahap & update?'),
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
                    if (ok != true) return;
                    try {
                      await ref.read(projectApiProvider).delete(p.id);
                      ref.invalidate(projectListProvider);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(apiMessage(e))));
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.red),
                  label: const Text('Hapus',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _Timeline(stages: p.stages),
          const SizedBox(height: 12),
          for (final s in p.stages) _StageCard(s: s, pid: p.id),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

/// Visualisasi timeline tahapan (paritas web Timeline, disederhanakan).
class _Timeline extends StatelessWidget {
  final List<ProjStage> stages;
  const _Timeline({required this.stages});

  @override
  Widget build(BuildContext context) {
    final dated = stages
        .where((s) => (s.planStart ?? '').isNotEmpty || (s.planEnd ?? '').isNotEmpty)
        .toList();
    if (dated.isEmpty) return const SizedBox.shrink();

    final ds = <DateTime>[];
    for (final s in dated) {
      for (final v in [s.planStart, s.planEnd]) {
        if (v != null && v.isNotEmpty) {
          final d = DateTime.tryParse(v);
          if (d != null) ds.add(d);
        }
      }
    }
    if (ds.isEmpty) return const SizedBox.shrink();
    final t0 = ds.reduce((a, b) => a.isBefore(b) ? a : b);
    final t1raw = ds.reduce((a, b) => a.isAfter(b) ? a : b);
    final now = DateTime.now();
    final t1 = t1raw.isAfter(now) ? t1raw : now;
    final spanMs = t1.difference(t0).inMilliseconds;
    final span = spanMs < 1 ? 1 : spanMs;

    double pct(String? v) {
      if (v == null || v.isEmpty) return 0;
      final d = DateTime.tryParse(v);
      if (d == null) return 0;
      final x = ((d.difference(t0).inMilliseconds) / span) * 100;
      return x.clamp(0, 100).toDouble();
    }

    final nowPct = (((now.difference(t0).inMilliseconds) / span) * 100)
        .clamp(0, 100)
        .toDouble();

    Color bar(String derived) {
      switch (derived) {
        case 'SELESAI':
          return Colors.green;
        case 'TERLAMBAT':
          return Colors.red;
        case 'AT_RISK':
          return Colors.amber;
        default:
          return Colors.blue;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Timeline tahapan',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final s in dated)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 86,
                    child: Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5)),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (c, box) {
                        final a = pct(s.planStart ?? s.planEnd);
                        final b = pct(s.planEnd ?? s.planStart);
                        final w = ((b - a).clamp(2, 100)) / 100 * box.maxWidth;
                        return SizedBox(
                          height: 16,
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              Positioned(
                                left: a / 100 * box.maxWidth,
                                top: 0,
                                child: Container(
                                  height: 16,
                                  width: w,
                                  decoration: BoxDecoration(
                                    color: bar(s.derived),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: nowPct / 100 * box.maxWidth,
                                top: 0,
                                child: Container(
                                    width: 1.5,
                                    height: 16,
                                    color: Colors.black),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: 38,
                    child: Text('${s.progress}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 10.5)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text('Garis hitam = hari ini. Merah = lewat rencana & belum selesai.',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _StageCard extends ConsumerWidget {
  final ProjStage s;
  final String pid;
  const _StageCard({required this.s, required this.pid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final canWrite = auth.can('project', 'edit') || auth.can('project', 'add');
    final range = [s.planStart, s.planEnd]
        .where((d) => d != null && d.isNotEmpty)
        .map(projFmtD)
        .join(' – ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.name,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
              ProjBadge(status: s.derived),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${range.isEmpty ? 'tanpa rencana tanggal' : range} • ${s.progress}%',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          if (canWrite)
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => showUpdateForm(context, ref, s.id, pid),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Update', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 32)),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        content: Text(
                            'Hapus tahap "${s.name}" beserta update-nya?'),
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
                    if (ok != true) return;
                    try {
                      await ref.read(projectApiProvider).deleteStage(s.id);
                      ref.invalidate(projectDetailProvider(pid));
                      ref.invalidate(projectListProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(apiMessage(e))));
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.red),
                  label: const Text('Hapus tahap',
                      style: TextStyle(fontSize: 12, color: Colors.red)),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 32)),
                ),
              ],
            ),
          const SizedBox(height: 4),
          if (s.updates.isEmpty)
            Text('Belum ada update.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400))
          else
            for (final u in s.updates) _UpdateRow(u: u, pid: pid),
        ],
      ),
    );
  }
}

class _UpdateRow extends ConsumerWidget {
  final ProjUpdate u;
  final String pid;
  const _UpdateRow({required this.u, required this.pid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final token = ref.watch(accessTokenProvider).value ?? '';
    final canWrite = auth.can('project', 'edit') || auth.can('project', 'add');

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(projFmtD(u.date),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              ProjBadge(status: u.status),
              const SizedBox(width: 6),
              Text('${u.progress}%', style: const TextStyle(fontSize: 11.5)),
              if ((u.createdBy ?? '').isNotEmpty)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text('oleh ${u.createdBy}',
                        style: TextStyle(
                            fontSize: 10.5, color: Colors.grey.shade600)),
                  ),
                )
              else
                const Spacer(),
              if (canWrite)
                GestureDetector(
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        content: const Text('Hapus update ini beserta fotonya?'),
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
                    if (ok != true) return;
                    try {
                      await ref.read(projectApiProvider).deleteUpdate(u.id);
                      ref.invalidate(projectDetailProvider(pid));
                      ref.invalidate(projectListProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(apiMessage(e))));
                      }
                    }
                  },
                  child: const Text('Hapus',
                      style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.red,
                          decoration: TextDecoration.underline)),
                ),
            ],
          ),
          if ((u.note ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(u.note!, style: const TextStyle(fontSize: 12)),
            ),
          if (u.photoList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final ph in u.photoList)
                    _PhotoThumb(
                        uid: u.id, ph: ph, token: token, canWrite: canWrite, pid: pid),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends ConsumerWidget {
  final String uid;
  final ProjPhoto ph;
  final String token;
  final bool canWrite;
  final String pid;
  const _PhotoThumb({
    required this.uid,
    required this.ph,
    required this.token,
    required this.canWrite,
    required this.pid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ProjectApi.photoUrl(uid, ph.id, token);
    return Stack(
      children: [
        GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (c) => Dialog(
              backgroundColor: Colors.black,
              insetPadding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Image.network(url, fit: BoxFit.contain)),
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Tutup')),
                ],
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        ),
        if (canWrite)
          Positioned(
            right: -6,
            top: -6,
            child: GestureDetector(
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    content: const Text('Hapus foto ini?'),
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
                if (ok != true) return;
                try {
                  await ref.read(projectApiProvider).deletePhoto(uid, ph.id);
                  ref.invalidate(projectDetailProvider(pid));
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(apiMessage(e))));
                  }
                }
              },
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
