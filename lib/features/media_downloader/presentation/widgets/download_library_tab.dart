import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/download_task.dart';
import '../../data/models/media_variant.dart';
import '../../data/services/download_manager_service.dart';

class DownloadLibraryTab extends StatelessWidget {
  final DownloadManagerService manager;
  final MediaKind? filter;
  final bool activeOnly;

  const DownloadLibraryTab({
    super.key,
    required this.manager,
    this.filter,
    this.activeOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    var items = activeOnly ? manager.active : manager.all;
    if (filter != null) {
      items = items.where((t) => t.kind == filter).toList();
    }

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No downloads yet.\nPaste or share a link to get started.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final task = items[index];
        return _DownloadTile(task: task, manager: manager);
      },
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadTask task;
  final DownloadManagerService manager;

  const _DownloadTile({required this.task, required this.manager});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_iconFor(task.kind)),
      title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.variantLabel, style: const TextStyle(fontSize: 12)),
          if (task.isActive)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(value: task.progress > 0 ? task.progress : null),
            ),
          if (task.status == DownloadStatus.failed && task.error != null)
            Text(task.error!, style: TextStyle(color: Colors.red.shade700, fontSize: 11)),
        ],
      ),
      trailing: _trailing(context),
    );
  }

  Widget? _trailing(BuildContext context) {
    return switch (task.status) {
      DownloadStatus.downloading || DownloadStatus.queued => IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => manager.cancel(task.id),
        ),
      DownloadStatus.failed => IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => manager.retry(task.id),
        ),
      DownloadStatus.completed => PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'share' && task.localPath != null) {
              await Share.shareXFiles([XFile(task.localPath!)]);
            } else if (v == 'delete') {
              await manager.delete(task.id);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'share', child: Text('Share')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      DownloadStatus.cancelled => IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => manager.retry(task.id),
        ),
    };
  }

  IconData _iconFor(MediaKind kind) => switch (kind) {
        MediaKind.video => Icons.videocam_outlined,
        MediaKind.audio => Icons.audiotrack_outlined,
        MediaKind.file => Icons.insert_drive_file_outlined,
      };
}
