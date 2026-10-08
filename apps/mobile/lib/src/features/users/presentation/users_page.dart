import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/auth/auth_notifier.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;
import 'package:mte_data_center/src/core/widgets/app_scaffold.dart';
import 'package:mte_data_center/src/core/widgets/error_view.dart';

import '../data/users_api.dart';
import '../domain/user_models.dart';
import 'users_providers.dart';

/// Manajemen User + izin per menu (khusus admin, route sudah diguard).
/// Meniru UsersPage: tambah, ubah role/password, hapus (konfirmasi),
/// matriks izin inputer/viewer (admin terkunci).
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final _nu = TextEditingController();
  final _np = TextEditingController();
  String _nr = 'inputer';
  bool _busy = false;

  @override
  void dispose() {
    _nu.dispose();
    _np.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_busy) return;
    if (_nu.text.trim().isEmpty || _np.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('username wajib & password min 4 karakter')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(usersApiProvider).create(
            username: _nu.text.trim(),
            password: _np.text,
            role: _nr,
          );
      _nu.clear();
      _np.clear();
      ref.invalidate(usersListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _del(String u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Hapus user $u?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(usersApiProvider).remove(u);
      ref.invalidate(usersListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiMessage(e))));
      }
    }
  }

  void _edit(AppUser u) {
    var role = u.role;
    final pw = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text('Ubah ${u.username}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final r in userRoles)
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) => setS(() => role = v ?? role),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pw,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password baru (kosongkan = tidak diubah)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                try {
                  await ref.read(usersApiProvider).patch(
                        u.username,
                        role: role,
                        password: pw.text.isEmpty ? null : pw.text,
                      );
                  ref.invalidate(usersListProvider);
                  if (context.mounted) Navigator.pop(c);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(apiMessage(e))));
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(PermRow row, String key, bool v) async {
    final next = switch (key) {
      'can_add' => row.copyWith(canAdd: v),
      'can_edit' => row.copyWith(canEdit: v),
      'can_delete' => row.copyWith(canDelete: v),
      _ => row.copyWith(canView: v),
    };
    if ((next.canAdd || next.canEdit || next.canDelete) && !next.canView) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tulis butuh hak Lihat — centang Lihat dulu.')),
        );
      }
      return;
    }
    try {
      await ref.read(usersApiProvider).setPerm(next);
      ref.invalidate(permsProvider);
      await ref.read(authProvider.notifier).refreshMe();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Users',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(usersListProvider);
          ref.invalidate(permsProvider);
          await ref.read(usersListProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text('Daftar user',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nu,
                    decoration: const InputDecoration(
                      labelText: 'username baru',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _np,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'password (min 4)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                DropdownButton<String>(
                  value: _nr,
                  items: [
                    for (final r in userRoles)
                      DropdownMenuItem(value: r, child: Text(r)),
                  ],
                  onChanged: (v) => setState(() => _nr = v ?? 'inputer'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _add,
                  child: Text(_busy ? '...' : '+ Tambah'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _UsersList(onEdit: _edit, onDelete: _del),
            const SizedBox(height: 16),
            const Text('Izin per menu (role admin terkunci penuh)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            _PermsSection(onToggle: _toggle),
          ],
        ),
      ),
    );
  }
}

class _UsersList extends ConsumerWidget {
  final void Function(AppUser u) onEdit;
  final void Function(String username) onDelete;
  const _UsersList({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider);
    return usersAsync.when(
      data: (users) => Card(
        child: Column(
          children: [
            for (final u in users)
              ListTile(
                title: Text(u.username),
                subtitle: Text(u.role),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => onEdit(u),
                      child: const Text('Ubah'),
                    ),
                    TextButton(
                      onPressed: () => onDelete(u.username),
                      child: const Text('Hapus',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(usersListProvider),
      ),
    );
  }
}

class _PermsSection extends ConsumerWidget {
  final Future<void> Function(PermRow row, String key, bool v) onToggle;
  const _PermsSection({required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permsAsync = ref.watch(permsProvider);
    return permsAsync.when(
      data: (perms) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final role in ['inputer', 'viewer'])
            _PermTable(role: role, perms: perms, onToggle: onToggle),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(permsProvider),
      ),
    );
  }
}

class _PermTable extends StatelessWidget {
  final String role;
  final List<PermRow> perms;
  final Future<void> Function(PermRow row, String key, bool v) onToggle;
  const _PermTable({
    required this.role,
    required this.perms,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final byMenu = {for (final p in perms) '${p.role}:${p.menu}': p};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(role, style: const TextStyle(fontWeight: FontWeight.bold)),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Menu')),
                DataColumn(label: Text('Lihat')),
                DataColumn(label: Text('Tambah')),
                DataColumn(label: Text('Ubah')),
                DataColumn(label: Text('Hapus')),
              ],
              rows: [
                for (final m in permMenus)
                  if (byMenu.containsKey('$role:$m'))
                    DataRow(cells: [
                      DataCell(Text(m)),
                      for (final k in ['can_view', 'can_add', 'can_edit', 'can_delete'])
                        DataCell(Checkbox(
                          value: switch (k) {
                            'can_add' => byMenu['$role:$m']!.canAdd,
                            'can_edit' => byMenu['$role:$m']!.canEdit,
                            'can_delete' => byMenu['$role:$m']!.canDelete,
                            _ => byMenu['$role:$m']!.canView,
                          },
                          onChanged: (nv) =>
                              onToggle(byMenu['$role:$m']!, k, nv ?? false),
                        )),
                    ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
