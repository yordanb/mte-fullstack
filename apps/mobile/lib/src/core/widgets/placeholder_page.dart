import 'package:flutter/material.dart';

import 'app_scaffold.dart';

/// Placeholder Milestone berikutnya (DBR, Performance, dst).
/// Route sudah didaftarkan agar guard + navigasi bisa direview sejak M1.
class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: title,
        body: Center(child: Text('$title — menyusul di milestone berikutnya')),
      );
}
