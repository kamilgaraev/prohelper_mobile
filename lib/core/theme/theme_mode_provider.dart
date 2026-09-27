import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../storage/secure_storage_service.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier(ref.read(secureStorageProvider));
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._storage) : super(ThemeMode.system) {
    _load();
  }

  final SecureStorageService _storage;

  Future<void> _load() async {
    try {
      final stored = await _storage.getThemeMode();
      if (!mounted) {
        return;
      }
      state = _parse(stored);
    } on MissingPluginException {
      return;
    } catch (_) {
      return;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      await _storage.saveThemeMode(mode.name);
    } on MissingPluginException {
      return;
    } catch (_) {
      return;
    }
  }

  ThemeMode _parse(String? raw) {
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
