import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_storage.dart';

/// Dark mode wajib: ThemeMode.system + toggle manual tersimpan (mte_theme).
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    Future.microtask(_load);
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final raw = await ref.read(tokenStorageProvider).readTheme();
    state = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(tokenStorageProvider).saveTheme(switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}

class AppTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1D6F42)),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D6F42),
          brightness: Brightness.dark,
        ),
      );
}
