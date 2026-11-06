import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';

/// Halaman placeholder PPM/Measurement/TAR Support — paritas web
/// (Ppm.tsx/Measurement.tsx/TarSupport.tsx): judul + subjudul + kartu
/// "konten menyusul". Dipakai 3 menu agar tidak ada halaman kosong.
class WebPlaceholderPage extends StatelessWidget {
  final String menuKey;
  final String title;
  final String subtitle;
  final String message;
  final IconData icon;

  const WebPlaceholderPage({
    super.key,
    required this.menuKey,
    required this.title,
    required this.subtitle,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: title,
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: Column(
                  children: [
                    Icon(icon, size: 44, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

/// PPM — Planned Preventive Maintenance (web Ppm.tsx).
class PpmPage extends StatelessWidget {
  const PpmPage({super.key});

  @override
  Widget build(BuildContext context) => const WebPlaceholderPage(
        menuKey: 'ppm',
        title: 'PPM',
        subtitle: 'Planned Preventive Maintenance',
        message:
            'Konten PPM akan diisi sesuai kriteria yang akan didefinisikan.',
        icon: Icons.check_circle_outline,
      );
}

/// Measurement (web Measurement.tsx).
class MeasurementPage extends StatelessWidget {
  const MeasurementPage({super.key});

  @override
  Widget build(BuildContext context) => const WebPlaceholderPage(
        menuKey: 'measurement',
        title: 'Measurement',
        subtitle: 'Catatan hasil pengukuran',
        message:
            'Konten Measurement akan diisi sesuai kriteria yang akan didefinisikan.',
        icon: Icons.straighten,
      );
}

/// TAR Support (web TarSupport.tsx).
class TarSupportPage extends StatelessWidget {
  const TarSupportPage({super.key});

  @override
  Widget build(BuildContext context) => const WebPlaceholderPage(
        menuKey: 'tarsupport',
        title: 'TAR Support',
        subtitle: 'Technical Advisory Report - Support',
        message:
            'Halaman TAR Support masih kosong. Konten akan diisi sesuai kebutuhan.',
        icon: Icons.track_changes,
      );
}
