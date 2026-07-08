import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../models/status_item.dart';
import '../services/file_repair_service.dart';
import '../services/gallery_service.dart';
import '../services/local_cache_service.dart';
import '../services/share_service.dart';
import '../services/status_actions_runner.dart';
import '../services/vault_service.dart';
import '../utils/format_utils.dart';
import '../widgets/app_audio_player.dart';
import '../widgets/app_video_player.dart';
import '../widgets/status_action_buttons.dart';

class StatusViewerScreen extends StatefulWidget {
  final StatusItem item;
  final List<StatusItem>? items;
  final int initialIndex;
  final LocalCacheService cache;
  final GalleryService gallery;
  final ShareService share;
  final FileRepairService? repair;
  final VaultService? vault;
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
    this.vault,
    this.onChanged,
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  final Map<String, String> _mediaPaths = {};

  List<StatusItem> get _allItems => widget.items ?? [widget.item];

  StatusItem get _item => _allItems[_currentIndex];

  Future<String> _pathFor(StatusItem item) async {
    if (_mediaPaths.containsKey(item.id)) return _mediaPaths[item.id]!;
    if (item.isVaulted && widget.vault != null) {
      final path = await widget.vault!.readablePath(item.displayPath, item.id);
      _mediaPaths[item.id] = path;
      return path;
    }
    return item.displayPath;
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _allItems.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _preloadMediaPaths();
  }

  Future<void> _preloadMediaPaths() async {
    for (final item in _allItems) {
      await _pathFor(item);
    }
    if (mounted) setState(() {});
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  void dispose() {
    _pageController.dispose();
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
    return FutureBuilder<String>(
      future: _pathFor(_item),
      builder: (context, snap) {
        final path = snap.data;
        if (path == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!File(path).existsSync()) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('File is missing. Try repairing from the status list.')),
          );
        }
        return _buildScaffold(path);
      },
    );
  }

  Widget _buildScaffold(String currentPath) {
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
              return FutureBuilder<String>(
                future: _pathFor(pageItem),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }
                  return Column(
                    children: [
                      Expanded(child: _buildBody(pageItem, index, snap.data!)),
                      _InfoBar(item: pageItem),
                    ],
                  );
                },
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

  Widget _buildBody(StatusItem item, int index, String path) {
    return switch (item.mediaType) {
      StatusMediaType.image => PhotoView(
          imageProvider: FileImage(File(path)),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
        ),
      StatusMediaType.video => AppVideoPlayer(
          key: ValueKey(path),
          filePath: path,
          showSkipButtons: _allItems.length > 1,
          onPrevious: index > 0 ? () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              ) : null,
          onNext: index < _allItems.length - 1 ? () => _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              ) : null,
        ),
      StatusMediaType.audio => ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: AppAudioPlayer(
            key: ValueKey(path),
            filePath: path,
            title: item.originalFileName ?? item.contactLabel,
            subtitle: item.contactLabel,
            playlistPaths: _audioPaths(),
            initialIndex: _audioIndex(item),
          ),
        ),
    };
  }

  List<String> _audioPaths() {
    return _allItems
        .where((i) => i.mediaType == StatusMediaType.audio)
        .map((i) => _mediaPaths[i.id] ?? i.displayPath)
        .where((p) => File(p).existsSync())
        .toList();
  }

  int _audioIndex(StatusItem item) {
    final audioItems = _allItems.where((i) => i.mediaType == StatusMediaType.audio).toList();
    final idx = audioItems.indexWhere((i) => i.id == item.id);
    return idx < 0 ? 0 : idx;
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
