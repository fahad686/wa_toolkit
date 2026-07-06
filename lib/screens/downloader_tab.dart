import 'package:flutter/material.dart';
import '../features/media_downloader/presentation/media_downloader_shell.dart';

/// Legacy entry — opens the full Media Downloader feature.
class DownloaderTab extends StatelessWidget {
  const DownloaderTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const MediaDownloaderShell();
  }
}
