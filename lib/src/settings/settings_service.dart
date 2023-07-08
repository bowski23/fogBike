import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service that stores and retrieves persistent user settings.
class SettingsService {

  /// Loads the User's preferred ThemeMode from local storage.
  Future<ThemeMode> themeMode() async {
    SharedPreferences instance = await SharedPreferences.getInstance();
    var themeStr = instance.getString("ThemeMode") ?? "system";
    return ThemeMode.values.byName(themeStr);
  }

  /// Persists the user's preferred ThemeMode to local storage.
  Future<void> updateThemeMode(ThemeMode theme) async {
    SharedPreferences instance = await SharedPreferences.getInstance();
    instance.setString("ThemeMode", theme.name);
  }
}
