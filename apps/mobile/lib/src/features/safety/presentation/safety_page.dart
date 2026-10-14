import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';

import 'bomak_view.dart';
import 'ribi_view.dart';
import 'safety_providers.dart';

/// Safety Bomak + R1BI dengan switch tampilan. Gate `bomak.view`
/// (meniru App.tsx). Meniru SafetyPage + RibiView web.
class SafetyPage extends ConsumerWidget {
  const SafetyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!auth.can('bomak', 'view')) {
      return const AppScaffold(
        title: 'Bomak R1BI',
        body: Center(
            child: Text('Role Anda tidak memiliki akses ke menu ini.')),
      );
    }
    final mode = ref.watch(safetyModeProvider);
    return AppScaffold(
      title: 'Bomak R1BI',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SegmentedButton<SafetyMode>(
              segments: const [
                ButtonSegment(
                    value: SafetyMode.bomak, label: Text('Bomak')),
                ButtonSegment(
                    value: SafetyMode.r1bi, label: Text('R1BI')),
              ],
              selected: {mode},
              onSelectionChanged: (s) {
                ref.read(safetyModeProvider.notifier).set(s.first);
              },
            ),
          ),
          Expanded(
            child: mode == SafetyMode.bomak
                ? const BomakView()
                : const RibiViewTab(),
          ),
        ],
      ),
    );
  }
}
