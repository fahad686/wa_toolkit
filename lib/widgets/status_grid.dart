import 'package:flutter/material.dart';
import '../models/status_item.dart';
import '../services/gallery_service.dart';
import '../services/status_actions_runner.dart';
import 'status_tile.dart';

class StatusGrid extends StatelessWidget {
  final List<StatusItem> items;
  final void Function(StatusItem item) onTap;
  final StatusActionsRunner? actionsRunner;
  final GalleryService? gallery;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<StatusItem>? onSelectionToggle;

  const StatusGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.actionsRunner,
    this.gallery,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.onSelectionToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Nothing here yet.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.62,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = selectedIds.contains(item.id);
        return Stack(
          children: [
            StatusTile(
              item: item,
              onTap: () {
                if (selectionMode) {
                  onSelectionToggle?.call(item);
                } else {
                  onTap(item);
                }
              },
              actionsRunner: selectionMode ? null : actionsRunner,
              gallery: selectionMode ? null : gallery,
            ),
            if (selectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: selected ? Theme.of(context).colorScheme.primary : Colors.white70,
                  child: Icon(
                    selected ? Icons.check : Icons.circle_outlined,
                    size: 18,
                    color: selected ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            if (item.isFavorite && !selectionMode)
              const Positioned(
                top: 8,
                left: 8,
                child: Icon(Icons.star, color: Colors.amber, size: 20),
              ),
          ],
        );
      },
    );
  }
}
