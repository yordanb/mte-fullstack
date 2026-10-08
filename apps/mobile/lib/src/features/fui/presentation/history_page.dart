import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/utils/date_fmt.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';

import 'fui_providers.dart';

/// Riwayat suggest 1 sample, terbaru dulu (modal web jadi halaman).
class SuggestHistoryPage extends ConsumerWidget {
  final String labNo;
  const SuggestHistoryPage({super.key, required this.labNo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histAsync = ref.watch(suggestHistoryProvider(labNo));
    return AppScaffold(
      title: 'Riwayat — Lab $labNo',
      body: histAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Belum ada suggest.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(suggestHistoryProvider(labNo));
              await ref.read(suggestHistoryProvider(labNo).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final s in items)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.suggestion),
                          const SizedBox(height: 4),
                          Text(
                            'PIC: ${s.pic ?? '-'} • oleh ${s.createdBy ?? '-'} • ${fmtDT(s.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(suggestHistoryProvider(labNo)),
        ),
      ),
    );
  }
}
