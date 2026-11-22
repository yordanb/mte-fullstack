import '../auth/auth_notifier.dart';

/// Satu entri menu drawer — meniru web Layout.tsx.
/// [key] HARUS sama dengan MENUS backend (apps/api .../users.py) agar
/// gating izin per role (tabel role_permissions) berfungsi.
class AppMenuEntry {
  final String key;
  final String label;
  final String path;
  final bool adminOnly;

  const AppMenuEntry({
    required this.key,
    required this.label,
    required this.path,
    this.adminOnly = false,
  });
}

/// Daftar menu drawer (urutan meniru web: Monitoring -> Administrasi).
const List<AppMenuEntry> appMenu = [
  // Monitoring
  AppMenuEntry(key: 'dashboard', label: 'Dashboard Oil Lab', path: '/'),
  AppMenuEntry(key: 'dbr', label: 'DBR Breakdown', path: '/dbr'),
  AppMenuEntry(key: 'performance', label: 'Performance', path: '/performance'),
  AppMenuEntry(key: 'timeline', label: 'Timeline Mingguan', path: '/timeline'),
  // Operasional
  AppMenuEntry(key: 'activity', label: 'Activity', path: '/activity'),
  AppMenuEntry(key: 'yazu_lighting', label: 'Yazu Lighting P2H', path: '/yazu'),
  AppMenuEntry(
      key: 'yazudc_lighting', label: 'Yazu Lighting Daily Check', path: '/yazudc'),
  AppMenuEntry(key: 'yazupumping', label: 'Yazu Pumping P2H', path: '/yazupumping'),
  AppMenuEntry(
      key: 'yazupumpingdc', label: 'Yazu Pumping Daily Check', path: '/yazupumpingdc'),
  AppMenuEntry(key: 'bomak', label: 'Bomak R1BI', path: '/bomak'),
  AppMenuEntry(key: 'equipment', label: 'Equipment', path: '/equipment'),
  AppMenuEntry(key: 'staging', label: 'Staging Pump', path: '/staging'),
  AppMenuEntry(key: 'mom', label: 'Meeting', path: '/mom'),
  AppMenuEntry(key: 'mom2', label: 'MOM Weekly SPEX', path: '/mom2'),
  AppMenuEntry(key: 'riwayat', label: 'Riwayat', path: '/riwayat'),
  AppMenuEntry(key: 'project', label: 'Project Management', path: '/project'),
  AppMenuEntry(key: 'import', label: 'Update Data', path: '/update-data'),
  // Follow Up
  AppMenuEntry(key: 'fui', label: 'FUI', path: '/fui'),
  AppMenuEntry(key: 'sugfui', label: 'Suggestion FUI', path: '/suggestion'),
  AppMenuEntry(key: 'fureport', label: 'Report Follow Up', path: '/report-followup'),
  // Technical Expert
  AppMenuEntry(key: 'hourmeter', label: 'Hourmeter', path: '/hourmeter'),
  AppMenuEntry(key: 'ppm', label: 'PPM', path: '/ppm'),
  AppMenuEntry(key: 'measurement', label: 'Measurement', path: '/measurement'),
  AppMenuEntry(key: 'ewacs', label: 'Ewacs Performance', path: '/ewacs'),
  AppMenuEntry(key: 'tarsupport', label: 'TAR Support', path: '/tarsupport'),
  AppMenuEntry(key: 'proker', label: 'Proker GMC Pompa Primer', path: '/proker'),
  AppMenuEntry(
      key: 'prokerbooster', label: 'Proker Midlife Eng Booster', path: '/prokerbooster'),
  AppMenuEntry(
      key: 'prokerinjector',
      label: 'Proker Midlife Injector Primer',
      path: '/prokerinjector'),
  AppMenuEntry(key: 'prokerthermo', label: 'Proker Thermostat CAT', path: '/prokerthermo'),
  AppMenuEntry(
      key: 'prokerpanel', label: 'Proker GMC Panel Booster', path: '/prokerpanel'),
  AppMenuEntry(
      key: 'prokerexhaust', label: 'Proker Gen Repair Exhaust', path: '/prokerexhaust'),
  AppMenuEntry(
      key: 'prokerexhaustmits', label: 'Proker Exhaust Mitsura', path: '/prokerexhaustmits'),
  AppMenuEntry(
      key: 'prokerfandrebb', label: 'Proker Rebearing Fan Drive', path: '/prokerfandrebb'),
  AppMenuEntry(
      key: 'prokerfandpompa', label: 'Proker Fan Drive Pompa', path: '/prokerfandpompa'),
  AppMenuEntry(
      key: 'prokergmc', label: 'Proker GMC Motor (2.000 Jam)', path: '/prokergmc'),
  AppMenuEntry(
      key: 'prokerfsbooster',
      label: 'Proker Fire Suppression Booster',
      path: '/prokerfsbooster'),
  AppMenuEntry(
      key: 'prokerfsprimer',
      label: 'Proker Fire Suppression Primer',
      path: '/prokerfsprimer'),
  AppMenuEntry(
      key: 'prokerponton', label: 'Proker General Repair Ponton', path: '/prokerponton'),
  // Agent
  AppMenuEntry(key: 'ss', label: 'Suggestion System', path: '/ss'),
  AppMenuEntry(key: 'ssab', label: 'SS AB', path: '/ssab'),
  AppMenuEntry(key: 'manpowermanage', label: 'Manpower', path: '/manpowermanage'),
  AppMenuEntry(key: 'manpower', label: 'Manpower Inovasi', path: '/manpower'),
  // Administrasi (khusus admin)
  AppMenuEntry(key: 'users', label: 'Users', path: '/users', adminOnly: true),
  AppMenuEntry(key: 'audit', label: 'Audit Log', path: '/audit', adminOnly: true),
];

/// Menu yang TAMPIL untuk user ini, mengikuti setting role:
/// * `adminOnly` -> hanya role admin.
/// * lainnya -> bila user punya izin "view" (Lihat) pada key menu tsb
///   (admin otomatis lolos semua).
List<AppMenuEntry> visibleMenus(AuthState auth) => [
      for (final m in appMenu)
        if (m.adminOnly ? auth.isAdmin : auth.can(m.key, 'view')) m,
    ];

/// Halaman awal setelah login: menu pertama yang diizinkan user
/// (bukan selalu Dashboard — mis. role tanpa izin dashboard mendarat
/// di menu ber-izin pertama). '/' bila tidak ada menu sama sekali.
String homePath(AuthState auth) {
  final v = visibleMenus(auth);
  return v.isEmpty ? '/' : v.first.path;
}

/// Entri menu untuk path rute tertentu (dipakai guard rute per izin).
AppMenuEntry? menuByPath(String path) {
  for (final m in appMenu) {
    if (m.path == path) return m;
  }
  return null;
}
