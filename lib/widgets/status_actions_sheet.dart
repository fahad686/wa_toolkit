import 'package:flutter/material.dart';
import '../models/status_item.dart';
import '../services/gallery_service.dart';
import '../services/local_cache_service.dart';
import '../services/share_service.dart';

typedef StatusActionCallback = Future<void> Function();

class StatusActionsSheet extends StatelessWidget {
  final StatusItem item;
  final LocalCacheService cache;
  final GalleryService gallery;
  final ShareService share;
  final StatusActionCallback onSave;
  final StatusActionCallback onSaveToGallery;
  final StatusActionCallback onVault;
  final StatusActionCallback onShare;
  final StatusActionCallback onDelete;
  final StatusActionCallback? onRepair;
  final VoidCallback onChanged;

  const StatusActionsSheet({
    super.key,
    required this.item,
    required this.cache,
    required this.gallery,
    required this.share,
    required this.onSave,
    required this.onSaveToGallery,
    required this.onVault,
    required this.onShare,
    required this.onDelete,
    this.onRepair,
    required this.onChanged,
  });

  static Future<String?> show(
    BuildContext context, {
    required StatusItem item,
    required LocalCacheService cache,
    required GalleryService gallery,
    required ShareService share,
    required StatusActionCallback onSave,
    required StatusActionCallback onSaveToGallery,
    required StatusActionCallback onVault,
    required StatusActionCallback onShare,
    required StatusActionCallback onDelete,
    StatusActionCallback? onRepair,
    required VoidCallback onChanged,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => StatusActionsSheet(
        item: item,
        cache: cache,
        gallery: gallery,
        share: share,
        onSave: onSave,
        onSaveToGallery: onSaveToGallery,
        onVault: onVault,
        onShare: onShare,
        onDelete: onDelete,
        onRepair: onRepair,
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _run(BuildContext context, Future<void> Function() action, String success) async {
    Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('View'),
            onTap: () => Navigator.pop(context, 'view'),
          ),
          if (item.isMissing && onRepair != null)
            ListTile(
              leading: const Icon(Icons.build_circle_outlined),
              title: const Text('Repair missing file'),
              onTap: () => _run(context, onRepair!, 'File repaired'),
            ),
          if (!item.isSaved && !item.isVaulted)
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined),
              title: const Text('Save in app'),
              subtitle: const Text('Keep beyond 24 hours'),
              onTap: () => _run(context, onSave, 'Saved permanently in app'),
            ),
          if (item.mediaType != StatusMediaType.audio)
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('Save to ${gallery.galleryLabelFor(item)}'),
              onTap: () => _run(context, onSaveToGallery, 'Saved to gallery'),
            ),
          if (!item.isVaulted)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Move to secure vault'),
              onTap: () => _run(context, onVault, 'Moved to vault'),
            ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share'),
            onTap: () => _run(context, onShare, 'Shared'),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
            title: Text('Delete', style: TextStyle(color: Colors.red.shade700)),
            onTap: () async {
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
              if (confirm == true && context.mounted) {
                await _run(context, onDelete, 'Deleted');
              }
            },
          ),
        ],
      ),
    );
  }
}
