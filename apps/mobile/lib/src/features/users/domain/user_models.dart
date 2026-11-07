/// Model Users + Audit — kontrak users.py admin routes + client.ts:100-143.
/// Role 9 + menu izin 29 disinkronkan dengan backend MENUS/ROLES users.py:15
/// (juga cermin apps/web/src/pages/Users.tsx:4-5).
class AppUser {
  final String username;
  final String role;
  const AppUser({required this.username, required this.role});

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        username: '${j['username'] ?? ''}',
        role: '${j['role'] ?? ''}',
      );
}

/// 9 role backend (users.py ROLES; urutan sama dengan web Users.tsx).
const userRoles = [
  'admin', 'inputer', 'mekanik', 'viewer', 'planner',
  'group leader', 'section head', 'adm te', 'adm lce',
];

/// Role yang tampil di matriks izin — admin dikecualikan karena izinnya
/// selalu penuh/terkunci (web Users.tsx:97).
const permMatrixRoles = [
  'inputer', 'mekanik', 'viewer', 'planner',
  'group leader', 'section head', 'adm te', 'adm lce',
];

/// 29 menu izin backend (users.py MENUS; urutan penting = urutan tampil web).
const permMenus = [
  'dashboard', 'dbr', 'performance', 'activity', 'equipment',
  'fui', 'sugfui', 'fureport', 'timeline', 'project', 'bomak',
  'staging', 'mom', 'riwayat', 'import', 'ppm', 'measurement',
  'yazu_lighting', 'yazudc_lighting', 'ewacs', 'tarsupport', 'ss', 'ssab',
  'proker', 'prokerbooster', 'prokerinjector', 'prokerthermo',
  'manpower', 'manpowermanage',
];

/// Label ramah baris matriks izin (web Users.tsx:110); menu lain apa adanya.
String menuLabel(String menu) => switch (menu) {
      'yazu_lighting' => 'yazu_lighting — Yazu Lighting P2H',
      'yazudc_lighting' => 'yazudc_lighting — Yazu Lighting Daily Check',
      'ss' => 'ss — Sugestion System',
      'ssab' => 'ssab — SS AB',
      'manpower' => 'manpower — Manpower Inovasi',
      'manpowermanage' => 'manpowermanage — Manajemen Manpower',
      'proker' => 'proker — GMC Pompa Primer',
      'prokerbooster' => 'prokerbooster — midlife eng booster',
      'prokerinjector' => 'prokerinjector — midlife injector primer',
      'prokerthermo' => 'prokerthermo — Thermostat CAT',
      _ => menu,
    };

class PermRow {
  final String role;
  final String menu;
  final bool canView;
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;

  const PermRow({
    required this.role,
    required this.menu,
    this.canView = false,
    this.canAdd = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  factory PermRow.fromJson(Map<String, dynamic> j) => PermRow(
        role: '${j['role'] ?? ''}',
        menu: '${j['menu'] ?? ''}',
        canView: j['can_view'] == true,
        canAdd: j['can_add'] == true,
        canEdit: j['can_edit'] == true,
        canDelete: j['can_delete'] == true,
      );

  PermRow copyWith({bool? canView, bool? canAdd, bool? canEdit, bool? canDelete}) =>
      PermRow(
        role: role,
        menu: menu,
        canView: canView ?? this.canView,
        canAdd: canAdd ?? this.canAdd,
        canEdit: canEdit ?? this.canEdit,
        canDelete: canDelete ?? this.canDelete,
      );

  Map<String, dynamic> toJson() => {
        'role': role,
        'menu': menu,
        'can_view': canView,
        'can_add': canAdd,
        'can_edit': canEdit,
        'can_delete': canDelete,
      };
}

class AuditRow {
  final int id;
  final String createdAt;
  final String? username;
  final String? role;
  final String method;
  final String path;
  final int status;
  final String? ip;
  final String? userAgent;

  const AuditRow({
    required this.id,
    required this.createdAt,
    this.username,
    this.role,
    required this.method,
    required this.path,
    required this.status,
    this.ip,
    this.userAgent,
  });

  factory AuditRow.fromJson(Map<String, dynamic> j) => AuditRow(
        id: (j['id'] as num?)?.toInt() ?? 0,
        createdAt: '${j['created_at'] ?? ''}',
        username: j['username']?.toString(),
        role: j['role']?.toString(),
        method: '${j['method'] ?? ''}',
        path: '${j['path'] ?? ''}',
        status: (j['status'] as num?)?.toInt() ?? 0,
        ip: j['ip']?.toString(),
        userAgent: j['user_agent']?.toString(),
      );
}

class AuditPageResult {
  final int total;
  final int page;
  final List<AuditRow> rows;
  const AuditPageResult({required this.total, required this.page, this.rows = const []});
}
