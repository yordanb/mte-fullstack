import 'package:flutter/material.dart';

import '../domain/project_models.dart';

/// Warna latar + teks chip status (web ST_STYLE).
( Color, Color ) projStatusColors(String? st) {
  switch (st ?? '') {
    case 'ON_TRACK':
      return (const Color(0xFFDCFCE7), const Color(0xFF15803D)); // green
    case 'AT_RISK':
      return (const Color(0xFFFEF9C3), const Color(0xFF854D0E)); // yellow
    case 'TERLAMBAT':
      return (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)); // red
    case 'SELESAI':
      return (const Color(0xFFEFF6FF), const Color(0xFF2563EB)); // brand/blue
    case 'BELUM_MULAI':
    default:
      return (const Color(0xFFF3F4F6), const Color(0xFF4B5563)); // gray
  }
}

/// Chip status kecil (paritas web `badge`).
class ProjBadge extends StatelessWidget {
  final String? status;
  const ProjBadge({super.key, this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = projStatusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        projStatusLabel(status ?? ''),
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// Tanggal `dd/MM/yyyy` dari `yyyy-MM-dd` (web `.split('-').reverse().join('/')`).
String projFmtD(String? v) {
  if (v == null || v.isEmpty) return '';
  final s = v.length >= 10 ? v.substring(0, 10) : v;
  final p = s.split('-');
  if (p.length != 3) return s;
  return '${p[2]}/${p[1]}/${p[0]}';
}
