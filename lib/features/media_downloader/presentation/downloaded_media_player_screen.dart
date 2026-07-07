import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../data/models/download_task.dart';
import 'widgets/download_actions.dart';

class DownloadedMediaPlayerScreen extends StatefulWidget {
  final DownloadTask task;

  const DownloadedMediaPlayerScreen({super.key, required this.task});

  @override
  State<DownloadedMediaPlayerScreen> createState() => _DownloadedMediaPlayerScreenState();
}

class _DownloadedMediaPlayerScreenState extends State<DownloadedMediaPlayerScreen> {
  VideoPlayerController? _controller;
  String? _error;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final path = widget.task.localPath;
    if (path == null || !File(path).existsSync()) {
      setState(() => _error = 'File not found on device.');
      return;
    }

    try {
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      controller.setLooping(true);
      await controller.play();
      if (mounted) {
        setState(() => _controller = controller);
        _scheduleHideControls();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Cannot play this file: $e');
    }
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.task.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              try {
                await DownloadActions.share(widget.task);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
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
      body: GestureDetector(
        onTap: _toggleControls,
        child: Center(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                )
              : _controller == null || !_controller!.value.isInitialized
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                        if (_showControls) ...[
                          IconButton(
                            iconSize: 64,
                            color: Colors.white70,
                            onPressed: () {
                              setState(() {
                                _controller!.value.isPlaying
                                    ? _controller!.pause()
                                    : _controller!.play();
                              });
                              _scheduleHideControls();
                            },
                            icon: Icon(
                              _controller!.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  VideoProgressIndicator(
                                    _controller!,
                                    allowScrubbing: true,
                                    colors: const VideoProgressColors(
                                      playedColor: Colors.redAccent,
                                      bufferedColor: Colors.white38,
                                      backgroundColor: Colors.white24,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      ValueListenableBuilder(
                                        valueListenable: _controller!,
                                        builder: (_, value, __) => Text(
                                          _format(value.position),
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ),
                                      ValueListenableBuilder(
                                        valueListenable: _controller!,
                                        builder: (_, value, __) => Text(
                                          _format(value.duration),
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
        ),
      ),
    );
  }

  Future<void> _menuAction(BuildContext context, String action) async {
    try {
      switch (action) {
        case 'gallery':
          await DownloadActions.saveToGalleryWithOverlay(context, widget.task);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to gallery')));
          }
        case 'vault':
          await DownloadActions.saveToVault(context, widget.task);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to vault')));
          }
        case 'favorite':
          await DownloadActions.toggleFavorite(widget.task);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Favorite updated')));
          }
        case 'playlist':
          await DownloadActions.addToPlaylist(context, widget.task);
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
            await DownloadActions.delete(widget.task);
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
