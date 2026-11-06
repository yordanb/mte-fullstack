import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_notifier.dart';
import '../theme/app_theme.dart';

/// Menu meniru web Layout.tsx:4-16. `adminOnly` khusus admin.
const List<Map<String, dynamic>> _menu = [
  {'key': 'dashboard', 'label': 'Dashboard Oil Lab', 'path': '/'},
  {'key': 'dbr', 'label': 'DBR Breakdown', 'path': '/dbr'},
  {'key': 'performance', 'label': 'Performance', 'path': '/performance'},
  {'key': 'timeline', 'label': 'Timeline Mingguan', 'path': '/timeline'},
  {'key': 'activity', 'label': 'Activity', 'path': '/activity'},
  {'key': 'bomak', 'label': 'Bomak R1BI', 'path': '/bomak'},
  {'key': 'mom', 'label': 'Meeting', 'path': '/mom'},
  {'key': 'equipment', 'label': 'Equipment', 'path': '/equipment'},
  {'key': 'fui', 'label': 'FUI', 'path': '/fui'},
  {'key': 'ss', 'label': 'Suggestion System', 'path': '/ss'},
  {'key': 'ssab', 'label': 'SS AB', 'path': '/ssab'},
  {'key': 'proker', 'label': 'Proker GMC Pompa Primer', 'path': '/proker'},
  {'key': 'prokerbooster', 'label': 'Proker Midlife Eng Booster', 'path': '/prokerbooster'},
  {'key': 'prokerinjector', 'label': 'Proker Midlife Injector Primer', 'path': '/prokerinjector'},
  {'key': 'prokerthermo', 'label': 'Proker Thermostat CAT', 'path': '/prokerthermo'},
  {'key': 'ppm', 'label': 'PPM', 'path': '/ppm'},
  {'key': 'hourmeter', 'label': 'Hourmeter', 'path': '/hourmeter'},
  {'key': 'yazu', 'label': 'Yazu P2H', 'path': '/yazu'},
  {'key': 'yazudc', 'label': 'Yazu Daily Check', 'path': '/yazudc'},
  {'key': 'ewacs', 'label': 'Ewacs Performance', 'path': '/ewacs'},
  {'key': 'riwayat', 'label': 'Riwayat', 'path': '/riwayat'},
  {'key': 'project', 'label': 'Project Management', 'path': '/project'},
  {'key': 'manpowermanage', 'label': 'Manpower', 'path': '/manpowermanage'},
  {'key': 'manpower', 'label': 'Manpower Inovasi', 'path': '/manpower'},
  {'key': 'staging', 'label': 'Staging Pump', 'path': '/staging'},
  {'key': 'measurement', 'label': 'Measurement', 'path': '/measurement'},
  {'key': 'tarsupport', 'label': 'TAR Support', 'path': '/tarsupport'},
  {'key': 'sugfui', 'label': 'Suggestion FUI', 'path': '/suggestion'},
  {'key': 'fureport', 'label': 'Report Follow Up', 'path': '/report-followup'},
  {'key': 'import', 'label': 'Update Data', 'path': '/update-data'},
  {'key': 'users', 'label': 'Users', 'path': '/users', 'adminOnly': true},
  {'key': 'audit', 'label': 'Audit Log', 'path': '/audit', 'adminOnly': true},
];

/// Scaffold + drawer dengan gating izin (sembunyikan menu tanpa view).
class AppScaffold extends ConsumerWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final theme = ref.watch(themeModeProvider);
    final visible = _menu.where((m) {
      if (m['adminOnly'] == true) return auth.isAdmin;
      return auth.can(m['key'] as String, 'view');
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Notifikasi',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            tooltip: theme == ThemeMode.dark ? 'Mode terang' : 'Mode gelap',
            icon: Icon(theme == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => ref
                .read(themeModeProvider.notifier)
                .setMode(theme == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark),
          ),
          if (actions != null) ...actions!,
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text(auth.username.isEmpty ? 'MTE Data Center' : auth.username),
                subtitle: Text(auth.role.isEmpty ? '' : auth.role),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: [
                    for (final m in visible)
                      ListTile(
                        title: Text(m['label'] as String),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go(m['path'] as String);
                        },
                      ),
                    const Divider(),
                    ListTile(title: const Text('Profil'), onTap: () => context.go('/profile')),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
