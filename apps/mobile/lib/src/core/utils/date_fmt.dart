// ignore_for_file: avoid_classes_with_only_static_members

/// Aturan tanggal handoff §6: kirim YYYY-MM-DD zona lokal perangkat
/// (JANGAN toISOString/UTC). Tampil DBR "12 Jul 26", log "dd/MM/yyyy HH:mm".
const List<String> _idMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
];

/// Untuk query/filter API: YYYY-MM-DD dari waktu lokal perangkat.
String toApiDate(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

DateTime? _parseLocal(String? v) {
  if (v == null || v.isEmpty) return null;
  try {
    return DateTime.parse(v).toLocal();
  } catch (_) {
    return null;
  }
}

String _p2(int n) => n.toString().padLeft(2, '0');

/// Kolom tabel oli: dd/MM/yyyy (web Widgets.tsx fmtDate).
String fmtDate(String? v) {
  final d = _parseLocal(v);
  if (d == null) return v ?? '';
  return '${_p2(d.day)}/${_p2(d.month)}/${d.year}';
}

/// DBR: "12 Jul 26" (tanpa pad, tahun 2 digit, bulan Indonesia).
String fmtDdbr(String? v) {
  final d = _parseLocal(v);
  if (d == null) return v ?? '';
  return '${d.day} ${_idMonths[d.month - 1]} ${d.year % 100}';
}

/// Log/notifikasi/last update: dd/MM/yyyy HH:mm (web Pages.tsx fmtDT).
String fmtDT(String? v) {
  final d = _parseLocal(v);
  if (d == null) return v ?? '';
  return '${_p2(d.day)}/${_p2(d.month)}/${d.year} ${_p2(d.hour)}:${_p2(d.minute)}';
}
