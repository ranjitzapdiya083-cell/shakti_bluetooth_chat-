import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import 'core_providers.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref ref;
  ThemeModeNotifier(this.ref) : super(_loadInitial(ref));

  static ThemeMode _loadInitial(Ref ref) {
    final raw = ref.read(storageServiceProvider).getSetting<String>(AppConstants.keyThemeMode);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(storageServiceProvider).setSetting(AppConstants.keyThemeMode, mode.name);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref);
});

class DynamicColorNotifier extends StateNotifier<bool> {
  final Ref ref;
  DynamicColorNotifier(this.ref)
      : super(ref.read(storageServiceProvider).getSetting<bool>(AppConstants.keyUseDynamicColor, defaultValue: true) ?? true);

  Future<void> toggle(bool value) async {
    state = value;
    await ref.read(storageServiceProvider).setSetting(AppConstants.keyUseDynamicColor, value);
  }
}

final useDynamicColorProvider = StateNotifierProvider<DynamicColorNotifier, bool>((ref) {
  return DynamicColorNotifier(ref);
});
