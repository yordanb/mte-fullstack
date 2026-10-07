import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/utils/date_fmt.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';

import '../data/activity_api.dart';
import 'activity_providers.dart';

/// Detail aktivitas + grid foto (tap = pratinjau). Hapus aktivitas/foto
/// gated `activity.delete`, Ubah gated `activity.edit` (meniru ActDetail web).
class ActivityDetailPage extends ConsumerWidget {
  final String id;
  const ActivityDetailPage({super.key, required this.id});

  Future<void> _delete(BuildContext context, WidgetRef ref, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus aktivitas?'),
        content: Text('"$title" beserta fotonya akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(activityApiProvider).remove(id);
      invalidateActivityLists(ref);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deletePhoto(
      BuildContext context, WidgetRef ref, String pid, VoidCallback reload) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus foto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(activityApiProvider).deletePhoto(id, pid);
      reload();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(activityDetailProvider(id));
    final tokenAsync = ref.watch(accessTokenProvider);
    final auth = ref.watch(authProvider);

    return detailAsync.when(
      data: (a) {
        final meta = [
          fmtDate(a.date),
          if ((a.crew ?? '').isNotEmpty) a.crew!,
          if ((a.category ?? '').isNotEmpty) a.category!,
          if ((a.cn ?? '').isNotEmpty) a.cn!,
          if (a.hm != null) 'HM ${a.hm}',
          if ((a.createdBy ?? '').isNotEmpty) 'oleh ${a.createdBy}',
        ].join(' • ');
        final token = switch (tokenAsync) {
          AsyncData(:final value) => value,
          _ => null,
        };
        return AppScaffold(
          title: a.title,
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(meta, style: Theme.of(context).textTheme.bodySmall),
              if ((a.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(a.description!),
              ],
              const SizedBox(height: 12),
              if (a.photos.isEmpty)
                const Center(child: Text('Belum ada foto.'))
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: a.photos.length,
                  itemBuilder: (c, i) {
                    final p = a.photos[i];
                    final url =
                        token == null ? null : ActivityApi.photoUrl(id, p.id, token);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        InkWell(
                          onTap: url == null
                              ? null
                              : () => showDialog(
                                    context: context,
                                    builder: (d) => Dialog(
                                      child: Image.network(
                                        url,
                                        errorBuilder: (_, __, ___) =>
                                            const Text('Gagal memuat foto'),
                                      ),
                                    ),
                                  ),
                          child: url == null
                              ? const Icon(Icons.image)
                              : Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (cx, child, prog) => prog == null
                                      ? child
                                      : const Center(
                                          child: CircularProgressIndicator()),
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image),
                                ),
                        ),
                        if (auth.can('activity', 'delete'))
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                                foregroundColor: Colors.white,
                              ),
                              tooltip: 'Hapus foto',
                              icon: const Icon(Icons.close),
                              onPressed: () => _deletePhoto(context, ref, p.id, () {
                                ref.invalidate(activityDetailProvider(id));
                                invalidateActivityLists(ref);
                              }),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (auth.can('activity', 'delete'))
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => _delete(context, ref, a.title),
                      child: const Text('Hapus'),
                    ),
                  const SizedBox(width: 8),
                  if (auth.can('activity', 'edit'))
                    FilledButton(
                      onPressed: () => context.push('/activity/$id/edit'),
                      child: const Text('Ubah'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const AppScaffold(
        title: 'Activity',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'Activity',
        body: ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(activityDetailProvider(id)),
        ),
      ),
    );
  }
}
