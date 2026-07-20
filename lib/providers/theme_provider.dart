import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the app's current theme mode (light / dark) and persists the
/// user's choice on-device so it's remembered the next time the app
/// opens. Any widget that calls context.watch<ThemeProvider>() rebuilds
/// automatically whenever the mode changes -- that's how flipping the
/// switch in Settings instantly re-themes the whole app.
class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'isDarkMode';

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// Call once at app startup to load the saved preference before the
  /// first frame, so the app doesn't flash the wrong theme briefly.
  Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_prefsKey) ?? false;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  Future<void> toggleDarkMode() => setDarkMode(!_isDarkMode);
}
