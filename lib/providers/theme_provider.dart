import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_settings_service.dart';

/// 可用主題定義
enum AppTheme {
  green('森林綠', Color(0xFF2E7D32), Color(0xFF66BB6A)),
  blue('海洋藍', Color(0xFF1565C0), Color(0xFF42A5F5)),
  purple('薰衣草紫', Color(0xFF6A1B9A), Color(0xFFAB47BC)),
  orange('暖陽橘', Color(0xFFE65100), Color(0xFFFF7043)),
  pink('玫瑰粉', Color(0xFFAD1457), Color(0xFFEC407A)),
  teal('薄荷青', Color(0xFF00695C), Color(0xFF26A69A));

  final String label;
  final Color lightSeed;
  final Color darkSeed;

  const AppTheme(this.label, this.lightSeed, this.darkSeed);
}

/// 主題模式 + 配色組合
class ThemeSettings {
  final ThemeMode mode;
  final AppTheme theme;

  const ThemeSettings({this.mode = ThemeMode.system, this.theme = AppTheme.green});
}

final themeSettingsProvider =
    StateNotifierProvider<ThemeSettingsNotifier, ThemeSettings>(
        (ref) => ThemeSettingsNotifier());

class ThemeSettingsNotifier extends StateNotifier<ThemeSettings> {
  ThemeSettingsNotifier() : super(const ThemeSettings()) {
    _load();
  }

  Future<void> _load() async {
    final modeStr = await AppSettingsService.get('theme_mode');
    final themeStr = await AppSettingsService.get('theme_color');

    final mode = switch (modeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final theme = AppTheme.values.firstWhere(
      (t) => t.name == themeStr,
      orElse: () => AppTheme.green,
    );

    state = ThemeSettings(mode: mode, theme: theme);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = ThemeSettings(mode: mode, theme: state.theme);
    final str = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await AppSettingsService.set('theme_mode', str);
  }

  Future<void> setTheme(AppTheme theme) async {
    state = ThemeSettings(mode: state.mode, theme: theme);
    await AppSettingsService.set('theme_color', theme.name);
  }
}
