import 'package:flutter/material.dart';
import '../features/media_downloader/presentation/media_downloader_shell.dart';
import '../features/vault/presentation/widgets/shimmer_vault_grid.dart';
import '../features/vault/presentation/widgets/vault_unlock_panel.dart';
import '../models/status_item.dart';
import '../services/gallery_service.dart';
import '../services/local_cache_service.dart';
import '../services/share_service.dart';
import '../services/status_actions_runner.dart';
import '../services/vault_note_service.dart';
import '../services/vault_service.dart';
import '../services/vault_local_import_service.dart';
import '../widgets/animated_loading_overlay.dart';
import '../widgets/status_grid.dart';
import 'status_viewer_screen.dart';

class VaultTab extends StatefulWidget {
  final LocalCacheService cache;
  final GalleryService gallery;
  final ShareService share;
  final VaultService vault;
  final VaultNoteService notes;

  const VaultTab({
    super.key,
    required this.cache,
    required this.gallery,
    required this.share,
    required this.vault,
    required this.notes,
  });

  @override
  State<VaultTab> createState() => _VaultTabState();
}

class _VaultTabState extends State<VaultTab> {
  static const _localImport = VaultLocalImportService();

  List<StatusItem> _items = [];
  List<VaultNote> _noteItems = [];
  bool _checking = true;
  bool _loading = true;
  bool _hasPin = false;
  bool _unlocked = false;
  String? _selectedFolder;
  VaultMediaFilter _filter = VaultMediaFilter.all;
  String _query = '';
  final _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _selectMode = false;
  VaultLockScreenStats? _lockStats;
  Duration? _lockout;
  bool _canBio = false;
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    widget.vault.addListener(_onVaultChanged);
    _init();
  }

  @override
  void dispose() {
    widget.vault.removeListener(_onVaultChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onVaultChanged() {
    if (mounted) {
      setState(() {
        _unlocked = widget.vault.isUnlocked;
      });
      if (_unlocked) _refresh();
    }
  }

  Future<void> _init() async {
    _hasPin = await widget.vault.hasPin();
    _unlocked = widget.vault.isUnlocked;
    await _loadLockStats();
    _lockout = await widget.vault.lockoutRemaining();
    _canBio = await widget.vault.canUseBiometric();
    _bioEnabled = await widget.vault.isBiometricEnabled();
    if (_unlocked) await _refresh();
    setState(() {
      _checking = false;
      _loading = false;
    });
  }

  Future<void> _loadLockStats() async {
    final stats = await widget.cache.vaultStats();
    _lockStats = VaultLockScreenStats(
      items: stats.itemCount,
      storageLabel: _formatBytes(stats.bytes),
      folders: stats.folderCount,
    );
  }

  Future<void> _refresh() async {
    widget.vault.touch();
    if (widget.vault.isDecoySession) {
      setState(() {
        _items = [];
        _noteItems = [];
      });
      return;
    }
    setState(() => _loading = true);
    final base = widget.cache.getVaultedInFolder(_selectedFolder);
    final filtered = widget.cache.filterVault(base, filter: _filter, query: _query);
    final notes = _filter == VaultMediaFilter.all && _query.isEmpty
        ? widget.notes.all()
        : widget.notes.all().where((n) {
            final q = _query.toLowerCase();
            return n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q);
          }).toList();
    await widget.cache.encryptLegacyVaultFiles();
    await widget.cache.ensureVaultThumbnails();
    if (mounted) {
      setState(() {
        _items = filtered;
        _noteItems = notes;
        _loading = false;
      });
    }
  }

  StatusActionsRunner _actionsRunner() => StatusActionsRunner(
        context: context,
        cache: widget.cache,
        gallery: widget.gallery,
        shareService: widget.share,
        onChanged: _refresh,
      );

  Future<void> _openViewer(StatusItem item) async {
    widget.vault.touch();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusViewerScreen(
          item: item,
          items: _items,
          initialIndex: _items.indexOf(item),
          cache: widget.cache,
          gallery: widget.gallery,
          share: widget.share,
          vault: widget.vault,
          onChanged: _refresh,
        ),
      ),
    ).then((_) => _refresh());
  }

  Future<bool> _setupPin(String pin) async {
    try {
      final ok = await widget.vault.setupInitialPin(pin);
      if (!ok) return false;
      setState(() {
        _hasPin = true;
        _unlocked = true;
      });
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vault PIN created — your files are now encrypted')),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
      return false;
    }
  }

  Future<bool> _unlockPin(String pin) async {
    _lockout = await widget.vault.lockoutRemaining();
    if (_lockout != null) return false;
    var ok = await widget.vault.verifyPin(pin);
    if (!ok) ok = await widget.vault.verifyDecoyPin(pin);
    if (!ok) {
      if (mounted) {
        _lockout = await widget.vault.lockoutRemaining();
        setState(() {});
      }
      return false;
    }
    setState(() => _unlocked = widget.vault.isUnlocked);
    await _refresh();
    return true;
  }

  Future<void> _importLocal() async {
    final paths = await _localImport.pickLocalPaths();
    if (paths == null || paths.isEmpty || !mounted) return;

    try {
      final count = await AnimatedLoadingOverlay.run(
        context,
        message: 'Hiding files in vault…',
        subtitle: '${paths.length} selected',
        icon: Icons.folder_off_outlined,
        task: () => _localImport.importPaths(cache: widget.cache, paths: paths),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count == 1
                  ? 'File hidden in vault'
                  : '$count files hidden in vault',
            ),
          ),
        );
      }
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _unlockBio() async {
    final ok = await widget.vault.unlockWithBiometric();
    if (ok) {
      setState(() => _unlocked = true);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Center(child: CircularProgressIndicator());

    if (!_hasPin || !_unlocked) {
      return VaultUnlockPanel(
        hasPin: _hasPin,
        canUseBiometric: _canBio,
        biometricEnabled: _bioEnabled,
        lockoutRemaining: _lockout,
        stats: _lockStats,
        onSetupPin: _setupPin,
        onUnlockPin: _unlockPin,
        onUnlockBiometric: _unlockBio,
      );
    }

    if (widget.vault.isDecoySession) {
      return const Center(child: Text('Vault is empty.', textAlign: TextAlign.center));
    }

    final folders = widget.cache.vaultFolders();
    final stats = _lockStats;

    return Column(
      children: [
        if (stats != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('${stats.items} items · ${stats.storageLabel} · encrypted')),
                IconButton(
                  tooltip: 'Lock vault',
                  icon: const Icon(Icons.lock_outline, size: 20),
                  onPressed: () {
                    widget.vault.lock();
                    setState(() => _unlocked = false);
                  },
                ),
              ],
            ),
          ),
        _FilterBar(
          filter: _filter,
          onChanged: (f) {
            setState(() => _filter = f);
            _refresh();
          },
        ),
        if (folders.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All folders'),
                  selected: _selectedFolder == null,
                  onSelected: (_) {
                    setState(() => _selectedFolder = null);
                    _refresh();
                  },
                ),
                ...folders.map((f) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: FilterChip(
                        label: Text(f),
                        selected: _selectedFolder == f,
                        onSelected: (_) {
                          setState(() => _selectedFolder = f);
                          _refresh();
                        },
                      ),
                    )),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search vault…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                        _refresh();
                      },
                    )
                  : null,
            ),
            onChanged: (v) {
              setState(() => _query = v);
              _refresh();
            },
          ),
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _selectMode = !_selectMode),
              icon: Icon(_selectMode ? Icons.close : Icons.checklist),
              label: Text(_selectMode ? 'Cancel' : 'Select'),
            ),
            TextButton.icon(onPressed: _addNote, icon: const Icon(Icons.note_add_outlined), label: const Text('Note')),
            TextButton.icon(
              onPressed: _importLocal,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Import'),
            ),
            if (_selectMode) ...[
              TextButton(onPressed: _bulkRestore, child: const Text('Restore')),
              TextButton(onPressed: _bulkDelete, child: const Text('Delete')),
            ],
          ],
        ),
        Expanded(
          child: _loading
              ? const ShimmerVaultGrid()
              : _items.isEmpty && _noteItems.isEmpty
                  ? _EmptyVault(
                      onImportDownloads: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MediaDownloaderShell()),
                      ),
                      onImportLocal: _importLocal,
                      onAddNote: _addNote,
                    )
                  : Column(
                  children: [
                    if (_noteItems.isNotEmpty)
                      SizedBox(
                        height: 120,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          children: _noteItems
                              .map((n) => ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.note_alt_outlined),
                                    title: Text(n.title.isEmpty ? 'Untitled' : n.title, maxLines: 1),
                                    onTap: () => _editNote(n),
                                  ))
                              .toList(),
                        ),
                      ),
                        if (_items.isNotEmpty)
                          Expanded(
                            child: StatusGrid(
                              items: _items,
                              onTap: _openViewer,
                              actionsRunner: _actionsRunner(),
                              gallery: widget.gallery,
                              cache: widget.cache,
                              selectionMode: _selectMode,
                              selectedIds: _selectedIds,
                              onSelectionToggle: (item) => setState(() {
                                if (_selectedIds.contains(item.id)) {
                                  _selectedIds.remove(item.id);
                                } else {
                                  _selectedIds.add(item.id);
                                }
                              }),
                            ),
                          ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _addNote() async {
    await _editNote(null);
  }

  Future<void> _editNote(VaultNote? existing) async {
    final titleC = TextEditingController(text: existing?.title ?? '');
    final bodyC = TextEditingController(text: existing?.body ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'New private note' : 'Edit note'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: bodyC, maxLines: 6, decoration: const InputDecoration(labelText: 'Note')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved == true) {
      await widget.notes.save(id: existing?.id, title: titleC.text, body: bodyC.text);
      _refresh();
    }
  }

  Future<void> _bulkRestore() async {
    var restored = 0;
    for (final id in _selectedIds) {
      final item = widget.cache.getById(id);
      if (item != null) {
        await widget.cache.restoreFromVault(item);
        restored++;
      }
    }
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
    if (mounted && restored > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored $restored item(s) to original location')),
      );
    }
    _refresh();
  }

  Future<void> _bulkDelete() async {
    for (final id in _selectedIds) {
      final item = widget.cache.getById(id);
      if (item != null) await widget.cache.deleteItem(item);
    }
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
    _refresh();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _FilterBar extends StatelessWidget {
  final VaultMediaFilter filter;
  final ValueChanged<VaultMediaFilter> onChanged;

  const _FilterBar({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {
      VaultMediaFilter.all: 'All',
      VaultMediaFilter.images: 'Images',
      VaultMediaFilter.videos: 'Video',
      VaultMediaFilter.audio: 'Music',
      VaultMediaFilter.favorites: 'Favorite',
      VaultMediaFilter.downloads: 'Downloads',
      VaultMediaFilter.local: 'Device',
      VaultMediaFilter.files: 'Files',
    };
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: VaultMediaFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = VaultMediaFilter.values[i];
          return ChoiceChip(
            label: Text(labels[f]!),
            selected: filter == f,
            onSelected: (_) => onChanged(f),
          );
        },
      ),
    );
  }
}

class _EmptyVault extends StatelessWidget {
  final VoidCallback onImportDownloads;
  final VoidCallback onImportLocal;
  final VoidCallback onAddNote;

  const _EmptyVault({
    required this.onImportDownloads,
    required this.onImportLocal,
    required this.onAddNote,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_special_outlined, size: 56),
            const SizedBox(height: 12),
            const Text('Vault is empty', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'Move statuses here, import from your device, save downloads, or add private notes.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onImportLocal,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Import from device'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: onImportDownloads, icon: const Icon(Icons.download_outlined), label: const Text('Import from Downloads')),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: onAddNote, icon: const Icon(Icons.note_add_outlined), label: const Text('Add private note')),
          ],
        ),
      ),
    );
  }
}
