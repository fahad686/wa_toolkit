import 'package:flutter/material.dart';
import '../../../app/bootstrap.dart';
import '../../../screens/settings_tab.dart';
import '../../../screens/statuses_home_screen.dart';
import '../../../screens/saved_tab.dart';
import '../../../screens/downloader_tab.dart';

class StatusSaverShell extends StatefulWidget {
  const StatusSaverShell({super.key});

  @override
  State<StatusSaverShell> createState() => _StatusSaverShellState();
}

class _StatusSaverShellState extends State<StatusSaverShell> {
  int _tab = 0;
  final _statusesKey = GlobalKey<StatusesHomeScreenState>();

  @override
  void initState() {
    super.initState();
    final s = AppServices.I;
    s.watch.onScanComplete = (_) => _statusesKey.currentState?.reloadAll();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppServices.I;
    final title = switch (_tab) {
      0 => 'Status Saver',
      1 => 'Saved',
      _ => 'Downloader',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsTab(
                  vault: s.vault,
                  scanner: s.scanner,
                  onFolderAccessChanged: () => _statusesKey.currentState?.reloadAll(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          StatusesHomeScreen(
            key: _statusesKey,
            cache: s.cache,
            scanner: s.scanner,
            gallery: s.gallery,
            share: s.share,
            repair: s.repair,
          ),
          SavedTab(cache: s.cache, gallery: s.gallery, share: s.share),
          DownloaderTab(downloader: s.downloader),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), label: 'Statuses'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), label: 'Saved'),
          NavigationDestination(icon: Icon(Icons.download_outlined), label: 'Download'),
        ],
      ),
    );
  }
}
