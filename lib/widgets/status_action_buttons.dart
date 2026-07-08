import 'package:flutter/material.dart';
import '../models/status_item.dart';
import '../services/gallery_service.dart';
import '../services/status_actions_runner.dart';

class _ActionDef {
  final IconData icon;
  final String tooltip;
  final Future<void> Function() onTap;
  final Color? color;

  const _ActionDef({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });
}

/// Horizontal action icons (same actions as the bottom sheet).
class StatusActionButtons extends StatelessWidget {
  final StatusItem item;
  final StatusActionsRunner runner;
  final GalleryService gallery;
  final bool compact;
  final Color? iconColor;
  final Color? backgroundColor;

  const StatusActionButtons({
    super.key,
    required this.item,
    required this.runner,
    required this.gallery,
    this.compact = false,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final actions = _buildActions();
    if (actions.isEmpty) return const SizedBox.shrink();

    final size = compact ? 28.0 : 36.0;
    final iconSize = compact ? 16.0 : 22.0;

    return Material(
      color: backgroundColor ?? (compact ? Colors.black.withValues(alpha: 0.55) : Colors.transparent),
      borderRadius: BorderRadius.circular(compact ? 6 : 8),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4, vertical: compact ? 2 : 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: actions.map((a) {
            return Tooltip(
              message: a.tooltip,
              triggerMode: TooltipTriggerMode.longPress,
              waitDuration: const Duration(milliseconds: 300),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.all(compact ? 4 : 8),
                constraints: BoxConstraints(minWidth: size, minHeight: size),
                iconSize: iconSize,
                color: a.color ?? iconColor ?? (compact ? Colors.white : null),
                onPressed: a.onTap,
                icon: Icon(a.icon),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<_ActionDef> _buildActions() {
    final list = <_ActionDef>[];

    if (item.isMissing && runner.repairService != null) {
      list.add(_ActionDef(
        icon: Icons.build_circle_outlined,
        tooltip: 'Repair missing file',
        onTap: () => runner.repair(item),
      ));
    }

    if (!item.isSaved && !item.isVaulted) {
      list.add(_ActionDef(
        icon: Icons.bookmark_add_outlined,
        tooltip: 'Save in app',
        onTap: () => runner.saveInApp(item),
      ));
    }

    if (item.mediaType != StatusMediaType.audio) {
      list.add(_ActionDef(
        icon: Icons.photo_library_outlined,
        tooltip: 'Save to ${gallery.galleryLabelFor(item)}',
        onTap: () => runner.saveToGallery(item),
      ));
    }

    if (item.isVaulted) {
      list.add(_ActionDef(
        icon: Icons.lock_open_outlined,
        tooltip: 'Restore from vault',
        onTap: () => runner.restoreFromVault(item),
      ));
    } else {
      list.add(_ActionDef(
        icon: Icons.lock_outline,
        tooltip: 'Move to secure vault',
        onTap: () => runner.moveToVault(item),
      ));
    }

    list.add(_ActionDef(
      icon: item.isFavorite ? Icons.star : Icons.star_border,
      tooltip: item.isFavorite ? 'Remove favorite' : 'Add favorite',
      color: item.isFavorite ? Colors.amber : null,
      onTap: () => runner.toggleFavorite(item),
    ));

    list.add(_ActionDef(
      icon: Icons.label_outline,
      tooltip: 'Add to collection',
      onTap: () => runner.addCollection(item),
    ));

    list.add(_ActionDef(
      icon: Icons.share_outlined,
      tooltip: 'Share',
      onTap: () => runner.share(item),
    ));

    list.add(_ActionDef(
      icon: Icons.delete_outline,
      tooltip: 'Delete',
      color: Colors.red.shade400,
      onTap: () => runner.delete(item),
    ));

    return list;
  }
}
