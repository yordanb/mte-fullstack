// Model Staging Pump — kontrak staging.py + client.ts.
// Struktur: group (baris) → pumps (untaian Primer → Booster).
// Mode mobile disederhanakan: tampilan kartu/tabel + pindah grup (tanpa drag-drop).

/// Daftar sistem pemompaan (web SYSTEMS).
const List<String> stagingSystems = [
  'SARABAKAWA',
  'MINI DREDGER',
  'Multi stage',
  'Transfer',
  'Single Stage',
  'Booster Dragflow',
];

/// Warna per role_order (web ROLE_COLORS) — (border ARGB, bg ARGB, text ARGB).
const List<(int, int, int)> _roleColors = [
  (0xFF10B981, 0xFFECFDF5, 0xFF047857), // 0 emerald
  (0xFF3B82F6, 0xFFEFF6FF, 0xFF1D4ED8), // 1 blue
  (0xFFF59E0B, 0xFFFFFBEB, 0xFFB45309), // 2 amber
  (0xFF8B5CF6, 0xFFF5F3FF, 0xFF6D28D9), // 3 purple
  (0xFF06B6D4, 0xFFECFEFF, 0xFF0E7490), // 4 cyan
  (0xFFF43F5E, 0xFFFFF1F2, 0xFFBE123C), // 5 rose
  (0xFF6366F1, 0xFFEEF2FF, 0xFF4338CA), // 6 indigo
];

/// (border, bg, text) untuk role_order; fallback ke indeks 6.
(int, int, int) stagingRoleColor(int n) =>
    n >= 0 && n < _roleColors.length ? _roleColors[n] : _roleColors[6];

/// Label role (Primer / Booster n) — cermin backend _role_label.
String stagingRoleLabel(int n) => n == 0 ? 'Primer' : 'Booster $n';

/// Satu pump item (web StagingPump).
class StagingPump {
  final int id;
  final String pumpCn;
  final int roleOrder;
  final String roleLabel;
  final String? unitType;
  final String? unitModel;

  const StagingPump({
    required this.id,
    required this.pumpCn,
    this.roleOrder = 0,
    this.roleLabel = 'Primer',
    this.unitType,
    this.unitModel,
  });

  factory StagingPump.fromJson(Map<String, dynamic> j) => StagingPump(
        id: (j['id'] as num?)?.toInt() ?? 0,
        pumpCn: '${j['pump_cn'] ?? ''}',
        roleOrder: (j['role_order'] as num?)?.toInt() ?? 0,
        roleLabel: j['role_label']?.toString() ??
            stagingRoleLabel((j['role_order'] as num?)?.toInt() ?? 0),
        unitType: j['unit_type']?.toString(),
        unitModel: j['unit_model']?.toString(),
      );
}

/// Satu grup staging (web StagingGroup).
class StagingGroup {
  final int id;
  final int groupNo;
  final String? sumpName;
  final String systemType;
  final bool isActive;
  final List<StagingPump> pumps;

  const StagingGroup({
    required this.id,
    required this.groupNo,
    this.sumpName,
    required this.systemType,
    this.isActive = true,
    this.pumps = const [],
  });

  /// Nama sump bersih (newline → spasi).
  String get sumpClean =>
      (sumpName ?? '').replaceAll('\n', ' ').trim();

  factory StagingGroup.fromJson(Map<String, dynamic> j) => StagingGroup(
        id: (j['id'] as num?)?.toInt() ?? 0,
        groupNo: (j['group_no'] as num?)?.toInt() ?? 0,
        sumpName: j['sump_name']?.toString(),
        systemType: '${j['system_type'] ?? ''}',
        isActive: j['is_active'] != false,
        pumps: ((j['pumps'] as List? ?? []))
            .map((e) => StagingPump.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// Riwayat perubahan (web StagingChange).
class StagingChange {
  final int id;
  final int groupId;
  final String period;
  final String changeType;
  final String? pumpCn;
  final String? fromValue;
  final String? toValue;
  final String changedBy;
  final String changedAt;
  final int groupNo;
  final String? sumpName;
  final String? systemType;

  const StagingChange({
    required this.id,
    required this.groupId,
    required this.period,
    required this.changeType,
    this.pumpCn,
    this.fromValue,
    this.toValue,
    this.changedBy = '',
    this.changedAt = '',
    this.groupNo = 0,
    this.sumpName,
    this.systemType,
  });

  factory StagingChange.fromJson(Map<String, dynamic> j) => StagingChange(
        id: (j['id'] as num?)?.toInt() ?? 0,
        groupId: (j['group_id'] as num?)?.toInt() ?? 0,
        period: '${j['period'] ?? ''}',
        changeType: '${j['change_type'] ?? ''}',
        pumpCn: j['pump_cn']?.toString(),
        fromValue: j['from_value']?.toString(),
        toValue: j['to_value']?.toString(),
        changedBy: '${j['changed_by'] ?? ''}',
        changedAt: '${j['changed_at'] ?? ''}',
        groupNo: (j['group_no'] as num?)?.toInt() ?? 0,
        sumpName: j['sump_name']?.toString(),
        systemType: j['system_type']?.toString(),
      );
}

// ─── Utilitas periode (web curPeriod/periodLabel/shiftPeriod) ──────

String _p2(int n) => n.toString().padLeft(2, '0');

/// Periode berjalan `YYYY-MM` dari tanggal lokal.
String stagingCurPeriod([DateTime? now]) {
  final d = now ?? DateTime.now();
  return '${d.year}-${_p2(d.month)}';
}

/// Geser periode sejumlah bulan (web shiftPeriod).
String stagingShiftPeriod(String period, int delta) {
  final parts = period.split('-');
  final y = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 2000;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
  final d = DateTime(y, m + delta, 1);
  return '${d.year}-${_p2(d.month)}';
}

const List<String> _monthsIdFull = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// "November 2026" (web periodLabel).
String stagingPeriodLabel(String p) {
  final parts = p.split('-');
  final y = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
  final idx = (m - 1).clamp(0, 11);
  return '${_monthsIdFull[idx]} $y';
}

/// Parse format cepat (web parseQuickGroup):
/// "Sump C3 [Transfer] - WP764 - WP1126" → (sump, system, cn[]).
/// Mengembalikan null bila format tidak valid.
({String sump, String system, List<String> cn})? stagingParseQuickGroup(
    String text) {
  final t = text
      .replaceAll(RegExp(r'[\u2011-\u2015\u2212]'), '-')
      .replaceAll('\t', '\n');
  final m = RegExp(r'^\s*(.+?)\s*\[(.+?)\]\s*[-:]?\s*([\s\S]*)$')
      .firstMatch(t);
  if (m == null) return null;
  final sump = m
      .group(1)!
      .replaceAll(RegExp(r'^[-:,\s]+|[-:,\s]+$'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  final system = m.group(2)!.trim();
  final cn = m
      .group(3)!
      .split(RegExp(r'[-,\n]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .map((s) => s.toUpperCase().replaceAll(RegExp(r'\s'), ''))
      .toList();
  if (sump.isEmpty || system.isEmpty || cn.isEmpty) return null;
  return (sump: sump, system: system, cn: cn);
}

/// Pecah teks untaian CN → daftar CN unik (web parsedCNs di beberapa tempat).
List<String> stagingParseChain(String text) {
  final arr = text
      .split('-')
      .map((s) => s.trim().toUpperCase().replaceAll(RegExp(r'\s'), ''))
      .where((s) => s.isNotEmpty)
      .toList();
  return arr.toSet().toList();
}
