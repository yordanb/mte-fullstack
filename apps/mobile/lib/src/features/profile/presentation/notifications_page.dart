import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mte_data_center/src/core/utils/date_fmt.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';

import '../data/profile_api.dart';

/// Notifikasi: 5 import terakhir + 5 aktivitas terbaru (NotifBell web
/// jadi halaman; tap menuju Update Data / Activity).
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(notificationsProvider);
    return AppScaffold(
      title: 'Notifikasi',
      body: notifAsync.when(
        data: (n) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(notificationsProvider);
            await ref.read(notificationsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text('Import terakhir',
                  style: Theme.of(context).textTheme.titleSmall),
              if (n.imports.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Belum ada import.'),
                )
              else
                for (final i in n.imports)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.circle,
                        size: 12,
                        color: i.status == 'COMMITTED'
                            ? Colors.green
                            : i.status == 'FAILED'
                                ? Colors.red
                                : Colors.yellow.shade700,
                      ),
                      title: Text(i.filename,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${i.status} • ok ${i.okRows}/${i.totalRows} • ${fmtDT(i.createdAt)}'),
                      onTap: () => context.go('/update-data'),
                    ),
                  ),
              const SizedBox(height: 8),
              Text('Aktivitas terbaru',
                  style: Theme.of(context).textTheme.titleSmall),
              if (n.activities.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Belum ada aktivitas.'),
                )
              else
                for (final a in n.activities)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.event_note, size: 16),
                      title: Text(a.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${[a.cn, a.createdBy].where((e) => (e ?? '').isNotEmpty).join(' • ')} • ${fmtDT(a.createdAt)}'),
                      onTap: () => context.go('/activity'),
                    ),
                  ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
      ),
    );
  }
}
