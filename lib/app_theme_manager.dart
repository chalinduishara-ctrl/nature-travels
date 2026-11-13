import 'package:flutter/material.dart';

// ============================================================================
// APP THEME CONTROLLER (LIGHT / DARK THEME STATE MANAGER)
// ============================================================================
class AppThemeManager extends ChangeNotifier {
  static final AppThemeManager instance = AppThemeManager._();
  AppThemeManager._();

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}
