import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'token_storage.dart';

/// Satu baris izin per menu: {view, add, edit, delete}.
class PermActions {
  final bool view;
  final bool add;
  final bool edit;
  final bool delete;

  const PermActions({this.view = false, this.add = false, this.edit = false, this.delete = false});

  factory PermActions.fromJson(Map<String, dynamic> j) => PermActions(
        view: j['view'] == true,
        add: j['add'] == true,
        edit: j['edit'] == true,
        delete: j['delete'] == true,
      );

  bool action(String act) => switch (act) {
        'view' => view,
        'add' => add,
        'edit' => edit,
        'delete' => delete,
        _ => false,
      };
}

/// Permissions dari GET /v1/users/me (handoff §4, 10 keys menu).
/// `vessel` dialiaskan ke `dashboard` seperti web client.ts:62.
class Permissions {
  final Map<String, PermActions> menus;
  const Permissions(this.menus);

  factory Permissions.fromJson(Map<String, dynamic> j) => Permissions(
        j.map((k, v) => MapEntry(k, v is Map<String, dynamic> ? PermActions.fromJson(v) : const PermActions())),
      );

  factory Permissions.fromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return const Permissions({});
    try {
      final j = jsonDecode(raw);
      if (j is Map<String, dynamic>) return Permissions.fromJson(j);
    } catch (_) {}
    return const Permissions({});
  }

  bool can(String menu, String act, {required bool isAdmin}) {
    if (isAdmin) return true;
    final m = menu == 'vessel' ? 'dashboard' : menu;
    return menus[m]?.action(act) ?? false;
  }

  Map<String, dynamic> toJson() => menus.map(
        (k, v) => MapEntry(k, {'view': v.view, 'add': v.add, 'edit': v.edit, 'delete': v.delete}),
      );
}

final permissionsProvider = FutureProvider<Permissions>((ref) async {
  final raw = await ref.watch(tokenStorageProvider).readPermRaw();
  return Permissions.fromRaw(raw);
});
