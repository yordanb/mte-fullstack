import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_notifier.dart';
import '../menu/app_menu.dart';
import '../theme/app_theme.dart';

/// Scaffold + drawer. Menu tampil mengikuti izin "Lihat" role user
/// (lihat `visibleMenus` di core/menu/app_menu.dart).
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
    // Menu tampil mengikuti setting role: adminOnly khusus admin,
    // sisanya bila user punya izin "view" pada key menu tsb.
    final visible = visibleMenus(auth);

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
                        title: Text(m.label),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go(m.path);
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
