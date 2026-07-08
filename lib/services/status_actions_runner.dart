import 'package:flutter/material.dart';
import '../models/status_item.dart';
import '../services/file_repair_service.dart';
import '../services/gallery_service.dart';
import '../services/local_cache_service.dart';
import '../services/share_service.dart';
import '../app/bootstrap.dart';

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

  Future<void> saveInApp(StatusItem item) => _run(() async {
        await cache.saveItem(item);
        await AppServices.I.autoVault.applyAfterSave(item);
        await _maybePromptVault(item);
      }, 'Saved permanently in app');

  Future<void> saveToGallery(StatusItem item) => _run(() async {
        if (!item.isSaved && !item.isVaulted) await cache.saveItem(item);
        final path = await cache.readableMediaPath(item);
        await gallery.saveToGallery(item, filePath: path);
        await _maybePromptVault(item);
      }, 'Saved to gallery');

  Future<void> moveToVault(StatusItem item, {String? folder}) async {
    if (folder == null) {
      folder = await _pickVaultFolder();
      if (!context.mounted) return;
    }
    await _run(
      () => cache.moveToVault(item, folder: folder),
      folder != null && folder.isNotEmpty ? 'Moved to vault / $folder' : 'Moved to vault',
    );
  }

  Future<void> restoreFromVault(StatusItem item) => _run(
        () => cache.restoreFromVault(item),
        'Restored from vault',
      );

  Future<void> toggleFavorite(StatusItem item) async {
    final wasFavorite = item.isFavorite;
    await _run(
      () => cache.toggleFavorite(item),
      wasFavorite ? 'Removed from favorites' : 'Added to favorites',
    );
  }

  Future<void> addCollection(StatusItem item) async {
    final tag = await _textDialog(title: 'Add to collection', label: 'Collection name');
    if (tag == null || tag.isEmpty || !context.mounted) return;
    await _run(() => cache.addCollectionTag(item, tag), 'Added to $tag');
  }

  Future<void> share(StatusItem item) => _run(() async {
        final path = await cache.readableMediaPath(item);
        await shareService.shareStatus(item, filePath: path);
      }, 'Shared');

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

  Future<void> bulkSave(Iterable<StatusItem> items) => _run(() async {
        for (final item in items) {
          if (!item.isSaved && !item.isVaulted) await cache.saveItem(item);
        }
      }, 'Saved ${items.length} item(s)');

  Future<void> bulkMoveToVault(Iterable<StatusItem> items) async {
    final folder = await _pickVaultFolder();
    if (!context.mounted) return;
    await _run(() async {
      for (final item in items) {
        await cache.moveToVault(item, folder: folder);
      }
    }, 'Moved ${items.length} item(s) to vault');
  }

  Future<void> bulkDelete(Iterable<StatusItem> items) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected?'),
        content: Text('Delete ${items.length} status(es)? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await _run(() async {
      for (final item in items) {
        await cache.deleteItem(item);
      }
    }, 'Deleted ${items.length} item(s)');
  }

  Future<void> _maybePromptVault(StatusItem item) async {
    if (!AppServices.I.prefs.promptVaultAfterSave) return;
    if (!context.mounted || item.isVaulted) return;
    final move = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to vault?'),
        content: const Text('You saved this status. Move it to the secure vault?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Move')),
        ],
      ),
    );
    if (move == true && context.mounted) {
      await moveToVault(item);
    }
  }

  Future<String?> _pickVaultFolder() async {
    final folders = cache.vaultFolders();
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      return _textDialog(title: 'New vault folder', label: 'Folder name');
    }
    return choice;
  }

  Future<String?> _textDialog({required String title, required String label}) {
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
