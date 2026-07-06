import 'package:flutter/material.dart';
import 'bootstrap.dart';
import 'theme/app_theme.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';

class WaToolkitApp extends StatelessWidget {
  const WaToolkitApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppServices.I.theme;
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) {
        return MaterialApp(
          title: 'WA Toolkit',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.mode,
          home: const DashboardScreen(),
        );
      },
    );
  }
}
