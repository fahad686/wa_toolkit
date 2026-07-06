import 'package:flutter/material.dart';
import '../models/status_item.dart';
import '../services/file_repair_service.dart';
import '../services/gallery_service.dart';
import '../services/local_cache_service.dart';
import '../services/share_service.dart';

/// Runs status actions (save, share, vault, delete, etc.) with snackbars.
class StatusActionsRunner {
  final BuildContext context;
  final LocalCacheService cache;
  final GalleryService gallery;
  final ShareService shareService;
  final FileRepairService? repairService;
  final VoidCallback onChanged;
  final VoidCallback? onDeleted;

  const StatusActionsRunner({
    required this.context,
    required this.cache,
    required this.gallery,
    required this.shareService,
    this.repairService,
    required this.onChanged,
    this.onDeleted,
  });

  Future<void> saveInApp(StatusItem item) => _run(
        () => cache.saveItem(item),
        'Saved permanently in app',
      );

  Future<void> saveToGallery(StatusItem item) => _run(() async {
        if (!item.isSaved && !item.isVaulted) await cache.saveItem(item);
        await gallery.saveToGallery(item);
      }, 'Saved to gallery');

  Future<void> moveToVault(StatusItem item) => _run(
        () => cache.moveToVault(item),
        'Moved to vault',
      );

  Future<void> share(StatusItem item) => _run(
        () => shareService.shareStatus(item),
        'Shared',
      );

  Future<void> repair(StatusItem item) => _run(
        () => repairService!.repairOne(item),
        'File repaired',
      );

  Future<void> delete(StatusItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete status?'),
        content: const Text('This removes the file from the app. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await _run(() => cache.deleteItem(item), 'Deleted');
    onDeleted?.call();
  }

  Future<void> _run(Future<dynamic> Function() action, String success) async {
    try {
      await action();
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
