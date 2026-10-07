// ignore_for_file: avoid_classes_with_only_static_members

/// Singkatan Unit Id khusus tampilan dashboard (DB tidak diubah).
/// Disalin persis dari apps/web/src/components/Widgets.tsx:12-35.
const Map<String, String> _unitShort = {
  'FINAL DRIVE LEFT': 'FD LH',
  'FINAL DRIVE RIGHT': 'FD RH',
  'FINAL DRIVE LEFT FRONT': 'FD LH FR',
  'FINAL DRIVE LEFT REAR': 'FD LH RR',
  'FINAL DRIVE LEFT CENTER': 'FD LH CTR',
  'FINAL DRIVE RIGHT FRONT': 'FD RH FR',
  'FINAL DRIVE RIGHT REAR': 'FD RH RR',
  'FINAL DRIVE RIGHT CENTER': 'FD RH CTR',
  'FINAL DRIVE': 'FD',
  'TRANSMISSION': 'TM',
  'DIFFERENTIAL CENTER': 'DIFF CTR',
  'DIFFERENTIAL FRONT': 'DIFF FR',
  'DIFFERENTIAL REAR': 'DIFF RR',
  'DIFFERENTIAL': 'DIFF',
  'HYDRAULIC': 'HYD',
  'TANDEM RIGHT': 'TDM RH',
  'TANDEM LEFT': 'TDM LH',
};

String shortUnit(String? v) {
  final u = (v ?? '').trim().toUpperCase();
  return _unitShort[u] ?? (v ?? '');
}
