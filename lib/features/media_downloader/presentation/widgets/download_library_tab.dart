import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/bootstrap.dart';
import '../../data/models/download_task.dart';
import '../../data/models/media_variant.dart';
import '../../data/services/download_manager_service.dart';
import '../../data/utils/download_file_utils.dart';
import '../../data/utils/download_format_utils.dart';
import '../downloaded_audio_player_screen.dart';
import '../downloaded_image_viewer_screen.dart';
import '../downloaded_media_player_screen.dart';
import 'download_actions.dart';
import 'shimmer_download_list.dart';

enum DownloadLibraryCategory {
  all,
  music,
  video,
  images,
  files,
  playlist,
  favorite,
}

class DownloadLibraryTab extends StatefulWidget {
  final DownloadManagerService manager;
  final bool activeOnly;

  const DownloadLibraryTab({
    super.key,
    required this.manager,
    this.activeOnly = false,
  });

  @override
  State<DownloadLibraryTab> createState() => _DownloadLibraryTabState();
}

class _DownloadLibraryTabState extends State<DownloadLibraryTab> {
  final _searchController = TextEditingController();
  String _query = '';
  int? _storageBytes;
  bool _loading = true;
  DownloadLibraryCategory _category = DownloadLibraryCategory.all;
  String? _selectedPlaylist;

  @override
  void initState() {
    super.initState();
    widget.manager.addListener(_refresh);
    _loadStorage();
  }

  @override
  void dispose() {
    widget.manager.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
      _loadStorage();
    }
  }

  Future<void> _loadStorage() async {
    final bytes = await widget.manager.totalStorageBytes();
    if (mounted) setState(() {
      _storageBytes = bytes;
      _loading = false;
    });
  }

  List<DownloadTask> _filterItems() {
    final prefs = AppServices.I.prefs;
    var items = widget.activeOnly
        ? widget.manager.active
        : widget.manager.all.where((t) => t.status == DownloadStatus.completed).toList();

    items = switch (_category) {
      DownloadLibraryCategory.all => items,
      DownloadLibraryCategory.music => items.where((t) => t.kind == MediaKind.audio).toList(),
      DownloadLibraryCategory.video => items.where((t) => t.kind == MediaKind.video).toList(),
      DownloadLibraryCategory.images => items.where(isDownloadImage).toList(),
      DownloadLibraryCategory.files => items.where(isDownloadFile).toList(),
      DownloadLibraryCategory.favorite =>
        items.where((t) => prefs.isFavoriteDownload(t.id)).toList(),
      DownloadLibraryCategory.playlist => _selectedPlaylist == null
          ? items
          : items
              .where((t) => prefs.downloadPlaylists[_selectedPlaylist]?.contains(t.id) ?? false)
              .toList(),
    };

    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      items = items
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              t.variantLabel.toLowerCase().contains(q) ||
              (t.platform?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    return items;
  }

  Future<void> _openItem(DownloadTask task) async {
    if (task.status != DownloadStatus.completed || task.localPath == null) return;
    final library = _filterItems()
        .where((t) => t.status == DownloadStatus.completed && t.localPath != null)
        .toList();
    Widget screen;
    if (task.kind == MediaKind.audio) {
      screen = DownloadedAudioPlayerScreen(task: task, playlist: library);
    } else if (isDownloadImage(task)) {
      screen = DownloadedImageViewerScreen(task: task);
    } else if (task.kind == MediaKind.video) {
      screen = DownloadedMediaPlayerScreen(task: task, playlist: library);
    } else {
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filterItems();
    final playlists = AppServices.I.prefs.downloadPlaylistNames;

    return Column(
      children: [
        if (_storageBytes != null && !widget.activeOnly && !_loading)
          _StorageBanner(
            bytes: _storageBytes!,
            completed: widget.manager.completedCount,
            failed: widget.manager.failedCount,
          ),
        if (!widget.activeOnly) _CategoryBar(
          category: _category,
          onChanged: (c) => setState(() {
            _category = c;
            if (c != DownloadLibraryCategory.playlist) _selectedPlaylist = null;
          }),
        ),
        if (!widget.activeOnly && _category == DownloadLibraryCategory.playlist)
          _PlaylistBar(
            playlists: playlists,
            selected: _selectedPlaylist,
            onSelect: (name) => setState(() => _selectedPlaylist = name),
            onCreate: () async {
              final name = await _newPlaylistDialog(context);
              if (name != null && name.isNotEmpty && mounted) {
                setState(() => _selectedPlaylist = name);
              }
            },
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search downloads…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: _loading
              ? const ShimmerDownloadList()
              : items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _emptyMessage(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final task = items[index];
                    return _DownloadTile(
                      task: task,
                      manager: widget.manager,
                      isFavorite: AppServices.I.prefs.isFavoriteDownload(task.id),
                      onOpen: () => _openItem(task),
                      onChanged: _refresh,
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _emptyMessage() {
    if (widget.activeOnly) return 'No active downloads.';
    return switch (_category) {
      DownloadLibraryCategory.favorite => 'No favorites yet.\nTap ★ on a download to add one.',
      DownloadLibraryCategory.playlist => _selectedPlaylist == null
          ? 'Select or create a playlist above.'
          : 'This playlist is empty.',
      DownloadLibraryCategory.music => 'No music downloads yet.',
      DownloadLibraryCategory.video => 'No video downloads yet.',
      DownloadLibraryCategory.images => 'No image downloads yet.',
      DownloadLibraryCategory.files => 'No file downloads yet.',
      DownloadLibraryCategory.all => 'No downloads yet.\nPaste or share a link to get started.',
    };
  }

  Future<String?> _newPlaylistDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Playlist name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await AppServices.I.prefs.createDownloadPlaylist(result);
    }
    return result;
  }
}

class _CategoryBar extends StatelessWidget {
  final DownloadLibraryCategory category;
  final ValueChanged<DownloadLibraryCategory> onChanged;

  const _CategoryBar({required this.category, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const categories = DownloadLibraryCategory.values;
    const labels = {
      DownloadLibraryCategory.all: 'All',
      DownloadLibraryCategory.music: 'Music',
      DownloadLibraryCategory.video: 'Video',
      DownloadLibraryCategory.images: 'Images',
      DownloadLibraryCategory.files: 'Files',
      DownloadLibraryCategory.playlist: 'Playlist',
      DownloadLibraryCategory.favorite: 'Favorite',
    };

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final c = categories[index];
          final selected = c == category;
          return ChoiceChip(
            label: Text(labels[c]!),
            selected: selected,
            onSelected: (_) => onChanged(c),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

class _PlaylistBar extends StatelessWidget {
  final List<String> playlists;
  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreate;

  const _PlaylistBar({
    required this.playlists,
    required this.selected,
    required this.onSelect,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('New'),
            onPressed: onCreate,
          ),
          const SizedBox(width: 8),
          ...playlists.map(
            (name) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(name),
                selected: selected == name,
                onSelected: (_) => onSelect(name),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageBanner extends StatelessWidget {
  final int bytes;
  final int completed;
  final int failed;

  const _StorageBanner({
    required this.bytes,
    required this.completed,
    required this.failed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.sd_storage_outlined, color: cs.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$completed saved · ${formatBytes(bytes)} used' +
                  (failed > 0 ? ' · $failed failed' : ''),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadTask task;
  final DownloadManagerService manager;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback onChanged;

  const _DownloadTile({
    required this.task,
    required this.manager,
    required this.isFavorite,
    required this.onOpen,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final failed = task.status == DownloadStatus.failed;
    final date = DateFormat.MMMd().add_jm().format(task.createdAt);
    final canOpen = task.status == DownloadStatus.completed &&
        task.localPath != null &&
        (task.kind == MediaKind.video || task.kind == MediaKind.audio || isDownloadImage(task));

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade400,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        if (task.isActive) return false;
        return true;
      },
      onDismissed: (_) async {
        await DownloadActions.delete(task);
        onChanged();
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: failed
              ? Colors.red.shade50
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(_iconFor(task), color: failed ? Colors.red : null, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (isFavorite) Icon(Icons.star, size: 16, color: Colors.amber.shade700),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${task.variantLabel} · $date', style: const TextStyle(fontSize: 11)),
            if (task.platform != null)
              Text(task.platform!, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            if (task.isActive) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(value: task.progress > 0 ? task.progress : null),
              Text(formatProgress(task.progress), style: const TextStyle(fontSize: 10)),
            ],
            if (task.status == DownloadStatus.completed && task.fileSizeBytes != null)
              Text(formatBytes(task.fileSizeBytes!), style: const TextStyle(fontSize: 10)),
            if (failed && task.error != null)
              Text(task.error!, style: TextStyle(color: Colors.red.shade700, fontSize: 11)),
          ],
        ),
        onTap: canOpen ? onOpen : null,
        trailing: _trailing(context),
      ),
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
          onSelected: (v) => _menu(context, v),
          itemBuilder: (_) => [
            if (task.kind == MediaKind.video || task.kind == MediaKind.audio || isDownloadImage(task))
              const PopupMenuItem(value: 'open', child: Text('Open')),
            if (task.kind == MediaKind.video || isDownloadImage(task))
              const PopupMenuItem(value: 'gallery', child: Text('Save to gallery')),
            const PopupMenuItem(value: 'vault', child: Text('Save to vault')),
            const PopupMenuItem(value: 'share', child: Text('Share')),
            PopupMenuItem(
              value: 'favorite',
              child: Text(isFavorite ? 'Remove favorite' : 'Add to favorite'),
            ),
            const PopupMenuItem(value: 'playlist', child: Text('Add to playlist')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      DownloadStatus.cancelled => IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => manager.retry(task.id),
        ),
    };
  }

  Future<void> _menu(BuildContext context, String action) async {
    try {
      switch (action) {
        case 'open':
          onOpen();
        case 'gallery':
          await DownloadActions.saveToGalleryWithOverlay(context, task);
          _snack(context, 'Saved to gallery');
        case 'vault':
          await DownloadActions.saveToVault(context, task);
          _snack(context, 'Saved to vault');
        case 'share':
          await DownloadActions.share(task);
        case 'favorite':
          await DownloadActions.toggleFavorite(task);
          onChanged();
          _snack(context, isFavorite ? 'Removed from favorites' : 'Added to favorites');
        case 'playlist':
          await DownloadActions.addToPlaylist(context, task);
          onChanged();
          _snack(context, 'Added to playlist');
        case 'delete':
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete download?'),
              content: const Text('This removes the file from your library.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
              ],
            ),
          );
          if (ok == true) {
            await DownloadActions.delete(task);
            onChanged();
          }
      }
    } catch (e) {
      _snack(context, '$e');
    }
  }

  void _snack(BuildContext context, String msg) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  IconData _iconFor(DownloadTask task) {
    if (isDownloadImage(task)) return Icons.image_outlined;
    return switch (task.kind) {
      MediaKind.video => Icons.videocam_outlined,
      MediaKind.audio => Icons.audiotrack_outlined,
      MediaKind.file => Icons.insert_drive_file_outlined,
    };
  }
}
