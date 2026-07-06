import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ThemeNotifier extends ChangeNotifier {
  static const _key = 'theme_mode';
  final Box _box;
  ThemeMode _mode = ThemeMode.system;

  ThemeNotifier(this._box) {
    final saved = _box.get(_key) as String?;
    _mode = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    await _box.put(_key, mode.name);
    notifyListeners();
  }

  void cycle() {
    final next = switch (_mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    setMode(next);
  }

  IconData get icon => switch (_mode) {
        ThemeMode.light => Icons.light_mode,
        ThemeMode.dark => Icons.dark_mode,
        ThemeMode.system => Icons.brightness_auto,
      };
}
