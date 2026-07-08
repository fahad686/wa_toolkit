import 'package:flutter/material.dart';
import 'bootstrap.dart';
import 'theme/app_theme.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/media_downloader/presentation/media_downloader_shell.dart';

class WaToolkitApp extends StatefulWidget {
  const WaToolkitApp({super.key});

  @override
  State<WaToolkitApp> createState() => _WaToolkitAppState();
}

class _WaToolkitAppState extends State<WaToolkitApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handleInitialShare();
    AppServices.I.shareLinks.links.listen(_onSharedLink);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      AppServices.I.vault.lock();
    }
    if (state == AppLifecycleState.resumed && AppServices.I.vault.shouldAutoLock()) {
      AppServices.I.vault.lock();
    }
  }

  Future<void> _handleInitialShare() async {
    final link = AppServices.I.shareLinks.consumePendingLink();
    if (link != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDownloader(link));
    }
  }

  void _onSharedLink(String link) {
    _openDownloader(link);
  }

  void _openDownloader(String link) {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(builder: (_) => MediaDownloaderShell(initialUrl: link)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppServices.I.theme;
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
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
