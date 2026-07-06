import 'package:flutter/material.dart';
import '../models/status_item.dart';
import '../services/gallery_service.dart';
import '../services/local_cache_service.dart';
import '../services/share_service.dart';
import '../services/status_actions_runner.dart';
import '../widgets/status_grid.dart';
import 'status_viewer_screen.dart';

class SavedTab extends StatefulWidget {
  final LocalCacheService cache;
  final GalleryService gallery;
  final ShareService share;

  const SavedTab({
    super.key,
    required this.cache,
    required this.gallery,
    required this.share,
  });

  @override
  State<SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends State<SavedTab> {
  List<StatusItem> _items = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _items = widget.cache.getSaved());

  StatusActionsRunner _actionsRunner() => StatusActionsRunner(
        context: context,
        cache: widget.cache,
        gallery: widget.gallery,
        shareService: widget.share,
        onChanged: _refresh,
      );

  void _openViewer(StatusItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusViewerScreen(
          item: item,
          cache: widget.cache,
          gallery: widget.gallery,
          share: widget.share,
          onChanged: _refresh,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Saved statuses appear here.\nTap the bookmark icon on any status to save.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return StatusGrid(
      items: _items,
      onTap: _openViewer,
      actionsRunner: _actionsRunner(),
      gallery: widget.gallery,
    );
  }
}
