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

  const StatusGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.actionsRunner,
    this.gallery,
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
        return StatusTile(
          item: item,
          onTap: () => onTap(item),
          actionsRunner: actionsRunner,
          gallery: gallery,
        );
      },
    );
  }
}
