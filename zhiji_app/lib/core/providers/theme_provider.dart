import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/common_daos.dart';

/// 全局主题模式状态，启动时从 settings_table 恢复
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ref),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._ref) : super(ThemeMode.system) {
    _load();
  }
  final Ref _ref;

  Future<void> _load() async {
    final db = await _ref.read(databaseProvider.future);
    final raw = await SettingsDao(db).getValue('theme_mode');
    state = _parse(raw);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final db = await _ref.read(databaseProvider.future);
    await SettingsDao(db).setValue('theme_mode', _key(mode));
  }

  static ThemeMode _parse(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
  static String _key(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      };
}
