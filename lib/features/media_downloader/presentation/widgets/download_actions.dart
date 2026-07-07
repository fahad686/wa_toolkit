import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../app/bootstrap.dart';
import '../../../../services/local_cache_service.dart';
import '../../../../widgets/animated_loading_overlay.dart';
import '../../data/models/download_task.dart';
import '../../data/models/media_variant.dart';
import '../../data/utils/download_file_utils.dart';

class DownloadActions {
  DownloadActions._();

  static Future<void> share(DownloadTask task) async {
    final path = task.localPath;
    if (path == null) throw StateError('File not available');
    await Share.shareXFiles([XFile(path)], text: task.title);
  }

  static Future<void> delete(DownloadTask task) async {
    await AppServices.I.downloadManager.delete(task.id);
    final prefs = AppServices.I.prefs;
    if (prefs.isFavoriteDownload(task.id)) {
      await prefs.toggleFavoriteDownload(task.id);
    }
    for (final playlist in prefs.playlistsForDownload(task.id)) {
      await prefs.removeDownloadFromPlaylist(task.id, playlist);
    }
  }

  static Future<void> saveToGallery(DownloadTask task) async {
    final path = task.localPath;
    if (path == null) throw StateError('File not available');
    if (task.kind == MediaKind.video || isDownloadImage(task)) {
      if (task.kind == MediaKind.video) {
        await Gal.putVideo(path);
      } else {
        await Gal.putImage(path);
      }
    } else {
      throw StateError('Only videos and images can be saved to gallery');
    }
  }

  static Future<void> saveToGalleryWithOverlay(BuildContext context, DownloadTask task) {
    return AnimatedLoadingOverlay.run(
      context,
      message: 'Saving to gallery',
      subtitle: task.title,
      icon: Icons.photo_library_outlined,
      task: () => saveToGallery(task),
    );
  }

  static Future<void> saveToVault(
    BuildContext context,
    DownloadTask task, {
    LocalCacheService? cache,
  }) async {
    final path = task.localPath;
    if (path == null) throw StateError('File not available');

    final folder = await _pickVaultFolder(context, cache ?? AppServices.I.cache);
    if (!context.mounted) return;

    await AnimatedLoadingOverlay.run(
      context,
      message: 'Saving to vault',
      subtitle: task.title,
      icon: Icons.lock_outline_rounded,
      task: () => (cache ?? AppServices.I.cache).importFileToVault(
        sourcePath: path,
        title: task.title,
        mediaType: statusTypeForDownload(task),
        folder: folder,
      ),
    );
  }

  static Future<void> toggleFavorite(DownloadTask task) async {
    await AppServices.I.prefs.toggleFavoriteDownload(task.id);
  }

  static Future<void> addToPlaylist(BuildContext context, DownloadTask task) async {
    final prefs = AppServices.I.prefs;
    final existing = prefs.downloadPlaylistNames;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Add to playlist')),
            ...existing.map(
              (name) => ListTile(
                leading: const Icon(Icons.queue_music_outlined),
                title: Text(name),
                onTap: () => Navigator.pop(ctx, name),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New playlist…'),
              onTap: () => Navigator.pop(ctx, '__new__'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;

    var playlistName = choice;
    if (choice == '__new__') {
      playlistName = await _textDialog(context, title: 'New playlist', label: 'Playlist name') ?? '';
      if (playlistName.isEmpty || !context.mounted) return;
    }

    await prefs.addDownloadToPlaylist(task.id, playlistName);
  }

  static Future<String?> _pickVaultFolder(BuildContext context, LocalCacheService cache) async {
    final folders = cache.vaultFolders();
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Save to vault')),
            ListTile(
              title: const Text('No folder'),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            ...folders.map(
              (f) => ListTile(title: Text(f), onTap: () => Navigator.pop(ctx, f)),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New folder…'),
              onTap: () => Navigator.pop(ctx, '__new__'),
            ),
          ],
        ),
      ),
    );
    if (choice == '__new__') {
      return _textDialog(context, title: 'New vault folder', label: 'Folder name');
    }
    return choice;
  }

  static Future<String?> _textDialog(
    BuildContext context, {
    required String title,
    required String label,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
