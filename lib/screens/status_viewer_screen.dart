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
  final List<StatusItem>? items;
  final int initialIndex;
  final LocalCacheService cache;
  final GalleryService gallery;
  final ShareService share;
  final FileRepairService? repair;
  final VoidCallback? onChanged;

  const StatusViewerScreen({
    super.key,
    required this.item,
    this.items,
    this.initialIndex = 0,
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
  late final PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController?> _videoControllers = {};
  final Map<int, bool> _videoReady = {};

  List<StatusItem> get _allItems => widget.items ?? [widget.item];

  StatusItem get _item => _allItems[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _allItems.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _initVideoFor(_currentIndex);
  }

  Future<void> _initVideoFor(int index) async {
    final item = _allItems[index];
    if (item.mediaType != StatusMediaType.video) return;
    if (_videoControllers[index] != null) return;

    final controller = VideoPlayerController.file(File(item.displayPath));
    await controller.initialize();
    controller.setLooping(true);
    await controller.play();
    if (mounted) {
      setState(() {
        _videoControllers[index] = controller;
        _videoReady[index] = true;
      });
    }
  }

  void _onPageChanged(int index) {
    _videoControllers[_currentIndex]?.pause();
    setState(() => _currentIndex = index);
    _initVideoFor(index);
    _videoControllers[index]?.play();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _videoControllers.values) {
      c?.dispose();
    }
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
          if (updated != null && mounted) setState(() {});
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
          PageView.builder(
            controller: _pageController,
            itemCount: _allItems.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final pageItem = _allItems[index];
              return Column(
                children: [
                  Expanded(child: _buildBody(pageItem, index)),
                  _InfoBar(item: pageItem),
                ],
              );
            },
          ),
          if (_allItems.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 4,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${_allItems.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
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

  Widget _buildBody(StatusItem item, int index) {
    return switch (item.mediaType) {
      StatusMediaType.image => PhotoView(
          imageProvider: FileImage(File(item.displayPath)),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
        ),
      StatusMediaType.video => _buildVideo(item, index),
      StatusMediaType.audio => _buildAudio(item),
    };
  }

  Widget _buildVideo(StatusItem item, int index) {
    final ready = _videoReady[index] == true;
    final controller = _videoControllers[index];
    if (!ready || controller == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            IconButton(
              iconSize: 64,
              color: Colors.white70,
              onPressed: () {
                setState(() {
                  controller.value.isPlaying ? controller.pause() : controller.play();
                });
              },
              icon: Icon(controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudio(StatusItem item) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.audiotrack, size: 96, color: Colors.white70),
          const SizedBox(height: 24),
          Text(
            item.originalFileName ?? 'Audio status',
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
