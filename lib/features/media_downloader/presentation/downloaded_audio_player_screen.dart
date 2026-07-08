import 'package:flutter/material.dart';
import '../../../../widgets/app_audio_player.dart';
import '../data/models/download_task.dart';
import 'widgets/download_actions.dart';

class DownloadedAudioPlayerScreen extends StatelessWidget {
  final DownloadTask task;
  final List<DownloadTask>? playlist;

  const DownloadedAudioPlayerScreen({
    super.key,
    required this.task,
    this.playlist,
  });

  @override
  Widget build(BuildContext context) {
    final tracks = playlist
            ?.where((t) => t.kind == task.kind && t.localPath != null)
            .toList() ??
        [task];
    final paths = tracks.map((t) => t.localPath!).toList();
    final index = tracks.indexWhere((t) => t.id == task.id).clamp(0, tracks.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(context, task),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _menuAction(context, v, task),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'vault', child: Text('Save to vault')),
              PopupMenuItem(value: 'favorite', child: Text('Toggle favorite')),
              PopupMenuItem(value: 'playlist', child: Text('Add to playlist')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: task.localPath == null
          ? const Center(child: Text('File not found on device.'))
          : AppAudioPlayer(
        key: ValueKey(task.id),
        filePath: task.localPath!,
        title: task.title,
        subtitle: task.variantLabel,
        playlistPaths: paths.length > 1 ? paths : null,
        initialIndex: index,
      ),
    );
  }

  Future<void> _share(BuildContext context, DownloadTask task) async {
    try {
      await DownloadActions.share(task);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _menuAction(BuildContext context, String action, DownloadTask task) async {
    try {
      switch (action) {
        case 'vault':
          await DownloadActions.saveToVault(context, task);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to vault')));
          }
        case 'favorite':
          await DownloadActions.toggleFavorite(task);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Favorite updated')));
          }
        case 'playlist':
          await DownloadActions.addToPlaylist(context, task);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to playlist')));
          }
        case 'delete':
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete download?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
              ],
            ),
          );
          if (ok == true) {
            await DownloadActions.delete(task);
            if (context.mounted) Navigator.pop(context);
          }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
