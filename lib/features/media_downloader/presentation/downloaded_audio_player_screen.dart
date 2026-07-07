import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../data/models/download_task.dart';
import 'widgets/download_actions.dart';

class DownloadedAudioPlayerScreen extends StatefulWidget {
  final DownloadTask task;
  final List<DownloadTask>? playlist;

  const DownloadedAudioPlayerScreen({
    super.key,
    required this.task,
    this.playlist,
  });

  @override
  State<DownloadedAudioPlayerScreen> createState() => _DownloadedAudioPlayerScreenState();
}

class _DownloadedAudioPlayerScreenState extends State<DownloadedAudioPlayerScreen> {
  AudioPlayer? _audio;
  String? _error;
  bool _ready = false;

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
      final player = AudioPlayer();
      await player.setFilePath(path);
      await player.play();
      if (mounted) {
        setState(() {
          _audio = player;
          _ready = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Cannot play audio: $e');
    }
  }

  @override
  void dispose() {
    _audio?.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
            onSelected: (v) => _menuAction(context, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'vault', child: Text('Save to vault')),
              PopupMenuItem(value: 'favorite', child: Text('Toggle favorite')),
              PopupMenuItem(value: 'playlist', child: Text('Add to playlist')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : !_ready || _audio == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Spacer(),
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(Icons.audiotrack, size: 80, color: cs.primary),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.task.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        widget.task.variantLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      StreamBuilder<Duration>(
                        stream: _audio!.positionStream,
                        builder: (context, posSnap) {
                          final pos = posSnap.data ?? Duration.zero;
                          return StreamBuilder<Duration?>(
                            stream: _audio!.durationStream,
                            builder: (context, durSnap) {
                              final dur = durSnap.data ?? Duration.zero;
                              final maxMs = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
                              return Column(
                                children: [
                                  Slider(
                                    value: pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble(),
                                    max: maxMs,
                                    onChanged: (v) => _audio!.seek(Duration(milliseconds: v.toInt())),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_format(pos), style: const TextStyle(fontSize: 12)),
                                        Text(_format(dur), style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 36,
                            onPressed: () async {
                              final pos = _audio!.position;
                              await _audio!.seek(pos - const Duration(seconds: 10));
                            },
                            icon: const Icon(Icons.replay_10),
                          ),
                          StreamBuilder<PlayerState>(
                            stream: _audio!.playerStateStream,
                            builder: (context, snap) {
                              final playing = snap.data?.playing ?? false;
                              return IconButton(
                                iconSize: 64,
                                onPressed: () => playing ? _audio!.pause() : _audio!.play(),
                                icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
                              );
                            },
                          ),
                          IconButton(
                            iconSize: 36,
                            onPressed: () async {
                              final pos = _audio!.position;
                              await _audio!.seek(pos + const Duration(seconds: 10));
                            },
                            icon: const Icon(Icons.forward_10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Future<void> _menuAction(BuildContext context, String action) async {
    try {
      switch (action) {
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
