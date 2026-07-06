import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import '../models/status_item.dart';
import '../services/file_repair_service.dart';
import '../services/gallery_service.dart';
import '../services/local_cache_service.dart';
import '../services/share_service.dart';
import '../services/status_actions_runner.dart';
import '../utils/format_utils.dart';
import '../widgets/status_action_buttons.dart';

class StatusViewerScreen extends StatefulWidget {
  final StatusItem item;
  final LocalCacheService cache;
  final GalleryService gallery;
  final ShareService share;
  final FileRepairService? repair;
  final VoidCallback? onChanged;

  const StatusViewerScreen({
    super.key,
    required this.item,
    required this.cache,
    required this.gallery,
    required this.share,
    this.repair,
    this.onChanged,
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen> {
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  late StatusItem _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    if (_item.mediaType == StatusMediaType.video) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.file(File(_item.displayPath));
    await controller.initialize();
    controller.setLooping(true);
    await controller.play();
    if (mounted) {
      setState(() {
        _videoController = controller;
        _videoReady = true;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  StatusActionsRunner get _runner => StatusActionsRunner(
        context: context,
        cache: widget.cache,
        gallery: widget.gallery,
        shareService: widget.share,
        repairService: widget.repair,
        onChanged: () {
          widget.onChanged?.call();
          final updated = widget.cache.getById(_item.id);
          if (updated != null && mounted) setState(() => _item = updated);
        },
        onDeleted: () {
          if (mounted) Navigator.pop(context);
        },
      );

  @override
  Widget build(BuildContext context) {
    final file = File(_item.displayPath);
    if (!file.existsSync()) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('File is missing. Try repairing from the status list.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(_item.contactLabel, style: const TextStyle(fontSize: 16)),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _buildBody()),
              _InfoBar(item: _item),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 4,
            right: 8,
            child: StatusActionButtons(
              item: _item,
              runner: _runner,
              gallery: widget.gallery,
              iconColor: Colors.white,
              backgroundColor: Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return switch (_item.mediaType) {
      StatusMediaType.image => PhotoView(
          imageProvider: FileImage(File(_item.displayPath)),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
        ),
      StatusMediaType.video => _buildVideo(),
      StatusMediaType.audio => _buildAudio(),
    };
  }

  Widget _buildVideo() {
    if (!_videoReady || _videoController == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_videoController!),
            IconButton(
              iconSize: 64,
              color: Colors.white70,
              onPressed: () {
                setState(() {
                  _videoController!.value.isPlaying
                      ? _videoController!.pause()
                      : _videoController!.play();
                });
              },
              icon: Icon(_videoController!.value.isPlaying ? Icons.pause_circle : Icons.play_circle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.audiotrack, size: 96, color: Colors.white70),
          const SizedBox(height: 24),
          Text(
            _item.originalFileName ?? 'Audio status',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          const Text('Open from share to play in your music app', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}

class _InfoBar extends StatelessWidget {
  final StatusItem item;
  const _InfoBar({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.black87,
      padding: const EdgeInsets.all(12),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.contactLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Captured: ${formatDateTime(item.discoveredAt)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            if (item.sourceModifiedAt != null)
              Text(
                'File time: ${formatDateTime(item.sourceModifiedAt!)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            if (item.deletedFromWhatsApp)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Deleted on WhatsApp — saved in this app',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
