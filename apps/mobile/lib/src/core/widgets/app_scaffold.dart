import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_notifier.dart';
import '../theme/app_theme.dart';

/// Menu meniru web Layout.tsx:4-16. `adminOnly` khusus admin.
const List<Map<String, dynamic>> _menu = [
  {'key': 'dashboard', 'label': 'Dashboard', 'path': '/'},
  {'key': 'dbr', 'label': 'DBR Breakdown', 'path': '/dbr'},
  {'key': 'performance', 'label': 'Performance', 'path': '/performance'},
  {'key': 'activity', 'label': 'Activity', 'path': '/activity'},
  {'key': 'equipment', 'label': 'Equipment', 'path': '/equipment'},
  {'key': 'fui', 'label': 'FUI', 'path': '/fui'},
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
