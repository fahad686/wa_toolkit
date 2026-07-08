import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../widgets/app_video_player.dart';
import '../data/models/download_task.dart';
import 'widgets/download_actions.dart';

class DownloadedMediaPlayerScreen extends StatefulWidget {
  final DownloadTask task;
  final List<DownloadTask>? playlist;

  const DownloadedMediaPlayerScreen({
    super.key,
    required this.task,
    this.playlist,
  });

  @override
  State<DownloadedMediaPlayerScreen> createState() => _DownloadedMediaPlayerScreenState();
}

class _DownloadedMediaPlayerScreenState extends State<DownloadedMediaPlayerScreen> {
  late int _index;
  late List<DownloadTask> _playlist;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist
            ?.where((t) => t.kind == widget.task.kind && t.localPath != null)
            .toList() ??
        [widget.task];
    _index = _playlist.indexWhere((t) => t.id == widget.task.id);
    if (_index < 0) _index = 0;
  }

  DownloadTask get _current => _playlist[_index];

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _playlist.length) return;
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final path = _current.localPath;
    final hasPlaylist = _playlist.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_current.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (hasPlaylist)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${_index + 1}/${_playlist.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) => _menuAction(context, v),
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
          ? const Center(
              child: Text('File not found on device.', style: TextStyle(color: Colors.white70)),
            )
          : AppVideoPlayer(
              key: ValueKey(path),
              filePath: path,
              showSkipButtons: hasPlaylist,
              onPrevious: _index > 0 ? () => _go(-1) : null,
              onNext: _index < _playlist.length - 1 ? () => _go(1) : null,
            ),
    );
  }

  Future<void> _share(BuildContext context) async {
    try {
      await DownloadActions.share(_current);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _menuAction(BuildContext context, String action) async {
    try {
      switch (action) {
        case 'gallery':
          await DownloadActions.saveToGalleryWithOverlay(context, _current);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to gallery')));
          }
        case 'vault':
          await DownloadActions.saveToVault(context, _current);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to vault')));
          }
        case 'favorite':
          await DownloadActions.toggleFavorite(_current);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Favorite updated')));
          }
        case 'playlist':
          await DownloadActions.addToPlaylist(context, _current);
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
            await DownloadActions.delete(_current);
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
