import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../data/models/download_task.dart';
import 'widgets/download_actions.dart';

class DownloadedImageViewerScreen extends StatelessWidget {
  final DownloadTask task;

  const DownloadedImageViewerScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final path = task.localPath;
    return Scaffold(
      appBar: AppBar(
        title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              try {
                await DownloadActions.share(task);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _action(context, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'gallery', child: Text('Save to gallery')),
              PopupMenuItem(value: 'vault', child: Text('Save to vault')),
              PopupMenuItem(value: 'favorite', child: Text('Toggle favorite')),
              PopupMenuItem(value: 'playlist', child: Text('Add to playlist')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: path == null || !File(path).existsSync()
          ? const Center(child: Text('Image not found'))
          : PhotoView(
              imageProvider: FileImage(File(path)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
            ),
    );
  }

  Future<void> _action(BuildContext context, String action) async {
    try {
      switch (action) {
        case 'gallery':
          await DownloadActions.saveToGalleryWithOverlay(context, task);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to gallery')));
          }
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
