import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Colors.teal;

  static ThemeData light() => ThemeData(
        colorSchemeSeed: _seed,
        useMaterial3: true,
        brightness: Brightness.light,
      );

  static ThemeData dark() => ThemeData(
        colorSchemeSeed: _seed,
        useMaterial3: true,
        brightness: Brightness.dark,
      );
}
