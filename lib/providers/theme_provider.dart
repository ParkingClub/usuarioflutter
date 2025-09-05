import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemePreference();
  }

  void toggleTheme() {
    // --- CORRECCIÓN AQUÍ ---
    // Se cambió Theme_Mode.system por ThemeMode.system
    _themeMode = _themeMode == ThemeMode.light || _themeMode == ThemeMode.system
        ? ThemeMode.dark
        : ThemeMode.light;

    _saveThemePreference();
    notifyListeners();
  }

  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final String theme = _themeMode == ThemeMode.light ? 'light' : 'dark';
    await prefs.setString('themeMode', theme);
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final String? theme = prefs.getString('themeMode');

    if (theme != null) {
      if (theme == 'light') {
        _themeMode = ThemeMode.light;
      } else if (theme == 'dark') {
        _themeMode = ThemeMode.dark;
      }
      notifyListeners();
    }
  }
}