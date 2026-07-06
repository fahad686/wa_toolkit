import 'package:flutter/material.dart';
import '../models/status_item.dart';
import '../services/file_repair_service.dart';
import '../services/gallery_service.dart';
import '../services/local_cache_service.dart';
import '../services/share_service.dart';
import '../services/status_scanner_service.dart';
import '../services/whatsapp_paths.dart';
import '../services/status_actions_runner.dart';
import '../widgets/shimmer_status_grid.dart';
import '../widgets/status_grid.dart';
import '../widgets/whatsapp_access_guide.dart';
import 'status_viewer_screen.dart';

class WhatsAppVariantTab extends StatefulWidget {
  final WhatsAppVariant variant;
  final LocalCacheService cache;
  final StatusScannerService scanner;
  final GalleryService gallery;
  final ShareService share;
  final FileRepairService repair;

  const WhatsAppVariantTab({
    super.key,
    required this.variant,
    required this.cache,
    required this.scanner,
    required this.gallery,
    required this.share,
    required this.repair,
  });

  @override
  State<WhatsAppVariantTab> createState() => WhatsAppVariantTabState();
}

class WhatsAppVariantTabState extends State<WhatsAppVariantTab>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<StatusItem> _items = [];
  bool _loading = false;
  bool _hasFolderAccess = false;
  StatusFilter _filter = StatusFilter.all;
  StatusDateFilter _dateFilter = StatusDateFilter.all;
  String? _contactFilter;
  String? _collectionFilter;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  int _missingCount = 0;
  String? _lastScanMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasFolderAccess && !_loading) {
      _scan(silent: true);
    }
  }

  Future<void> reload() => _bootstrap();

  Future<void> _bootstrap() async {
    _hasFolderAccess = await widget.scanner.restoreAccess(widget.variant);
    await widget.cache.sweepExpired();
    await _refreshList();
    if (_hasFolderAccess) await _scan(silent: true);
    if (mounted) setState(() {});
  }

  Future<void> _refreshList() async {
    await widget.repair.findMissing();
    if (!mounted) return;
    setState(() {
      _items = widget.cache.filter(
        _filter,
        variant: widget.variant,
        dateFilter: _dateFilter,
        contactQuery: _contactFilter,
        collectionTag: _collectionFilter,
      );
      _missingCount = widget.cache.getMissing(variant: widget.variant).length;
    });
  }

  Future<void> _grantAccess() async {
    final granted = await widget.scanner.requestFolderAccess(widget.variant);
    if (!mounted) return;
    if (granted) {
      setState(() => _hasFolderAccess = true);
      await _scan();
    }
  }

  Future<void> _scan({bool silent = false}) async {
    setState(() => _loading = true);
    try {
      final result = await widget.scanner.scanAndCacheNewStatuses(widget.variant);
      await widget.cache.sweepExpired();
      await _refreshList();

      final message = _messageForScan(result);
      setState(() => _lastScanMessage = message);

      if (mounted && (!silent || result.newlyCached > 0)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageForScan(ScanResult result) {
    if (!result.foundStatusesFolder) {
      return 'Wrong folder — re-grant and select .Statuses for ${widget.variant.shortLabel}.';
    }
    if (result.filesSeen == 0) {
      return 'No files in folder. View statuses in ${widget.variant.label} first.';
    }
    if (result.newlyCached > 0) {
      return '${result.newlyCached} new status(es) captured.';
    }
    if (result.markedDeleted > 0) {
      return '${result.markedDeleted} status(es) deleted on WhatsApp — still saved here.';
    }
    return 'Scanned ${result.filesSeen} file(s).';
  }

  StatusActionsRunner _actionsRunner() => StatusActionsRunner(
        context: context,
        cache: widget.cache,
        gallery: widget.gallery,
        shareService: widget.share,
        repairService: widget.repair,
        onChanged: _refreshList,
      );

  void _openViewer(StatusItem item) {
    final index = _items.indexWhere((i) => i.id == item.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusViewerScreen(
          item: item,
          items: _items,
          initialIndex: index < 0 ? 0 : index,
          cache: widget.cache,
          gallery: widget.gallery,
          share: widget.share,
          repair: widget.repair,
          onChanged: _refreshList,
        ),
      ),
    );
  }

  void _toggleSelection(StatusItem item) {
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  List<StatusItem> get _selectedItems =>
      _items.where((i) => _selectedIds.contains(i.id)).toList();

  Future<void> _runBulk(Future<void> Function(List<StatusItem>) action) async {
    final selected = _selectedItems;
    if (selected.isEmpty) return;
    await action(selected);
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
    await _refreshList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_hasFolderAccess) {
      return WhatsAppAccessGuide(
        variant: widget.variant,
        hasAccess: false,
        onGrantAccess: _grantAccess,
      );
    }

    return Column(
      children: [
        _TopBar(
          variant: widget.variant,
          loading: _loading,
          missingCount: _missingCount,
          selectionMode: _selectionMode,
          selectedCount: _selectedIds.length,
          onRefresh: () => _scan(),
          onShowGuide: () => _showGuideSheet(),
          onRegrant: _grantAccess,
          onToggleSelection: () => setState(() {
            _selectionMode = !_selectionMode;
            if (!_selectionMode) _selectedIds.clear();
          }),
          onBulkSave: () => _runBulk((items) => _actionsRunner().bulkSave(items)),
          onBulkVault: () => _runBulk((items) => _actionsRunner().bulkMoveToVault(items)),
          onBulkDelete: () => _runBulk((items) => _actionsRunner().bulkDelete(items)),
        ),
        _FilterBar(
          filter: _filter,
          dateFilter: _dateFilter,
          contactFilter: _contactFilter,
          collectionFilter: _collectionFilter,
          collections: widget.cache.collectionTags(variant: widget.variant),
          onFilterChanged: (f) async {
            setState(() => _filter = f);
            await _refreshList();
          },
          onDateFilterChanged: (f) async {
            setState(() => _dateFilter = f);
            await _refreshList();
          },
          onContactFilterChanged: (v) async {
            setState(() => _contactFilter = v);
            await _refreshList();
          },
          onCollectionFilterChanged: (v) async {
            setState(() => _collectionFilter = v);
            await _refreshList();
          },
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _scan(),
            child: _loading && _items.isEmpty
                ? const ShimmerStatusGrid()
                : _items.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 48),
                          Icon(Icons.visibility_outlined, size: 48, color: Colors.grey.shade500),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'No ${widget.variant.shortLabel} statuses yet.\n\n'
                              '1. Open ${widget.variant.label} and view statuses\n'
                              '2. Pull down here to refresh\n\n'
                              'App scans every 20s while open to catch deleted statuses.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (_lastScanMessage != null) ...[
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                _lastScanMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.orange.shade800),
                              ),
                            ),
                          ],
                        ],
                      )
                    : StatusGrid(
                        items: _items,
                        onTap: _openViewer,
                        actionsRunner: _actionsRunner(),
                        gallery: widget.gallery,
                        selectionMode: _selectionMode,
                        selectedIds: _selectedIds,
                        onSelectionToggle: _toggleSelection,
                      ),
          ),
        ),
      ],
    );
  }

  void _showGuideSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: WhatsAppAccessGuide(
          variant: widget.variant,
          hasAccess: _hasFolderAccess,
          onGrantAccess: () {
            Navigator.pop(context);
            _grantAccess();
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final WhatsAppVariant variant;
  final bool loading;
  final int missingCount;
  final bool selectionMode;
  final int selectedCount;
  final VoidCallback onRefresh;
  final VoidCallback onShowGuide;
  final VoidCallback onRegrant;
  final VoidCallback onToggleSelection;
  final VoidCallback onBulkSave;
  final VoidCallback onBulkVault;
  final VoidCallback onBulkDelete;

  const _TopBar({
    required this.variant,
    required this.loading,
    required this.missingCount,
    required this.selectionMode,
    required this.selectedCount,
    required this.onRefresh,
    required this.onShowGuide,
    required this.onRegrant,
    required this.onToggleSelection,
    required this.onBulkSave,
    required this.onBulkVault,
    required this.onBulkDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (selectionMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
        child: Row(
          children: [
            Text('$selectedCount selected', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(icon: const Icon(Icons.bookmark_add_outlined), onPressed: onBulkSave),
            IconButton(icon: const Icon(Icons.lock_outline), onPressed: onBulkVault),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: onBulkDelete),
            IconButton(icon: const Icon(Icons.close), onPressed: onToggleSelection),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
      child: Row(
        children: [
          Chip(
            avatar: Icon(
              variant == WhatsAppVariant.business ? Icons.business : Icons.chat,
              size: 16,
            ),
            label: Text('${variant.shortLabel} connected'),
          ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.checklist), tooltip: 'Select', onPressed: onToggleSelection),
          IconButton(icon: const Icon(Icons.help_outline), tooltip: 'Guide', onPressed: onShowGuide),
          IconButton(icon: const Icon(Icons.folder_open), tooltip: 'Re-grant folder', onPressed: onRegrant),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Scan now',
            onPressed: loading ? null : onRefresh,
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final StatusFilter filter;
  final StatusDateFilter dateFilter;
  final String? contactFilter;
  final String? collectionFilter;
  final List<String> collections;
  final ValueChanged<StatusFilter> onFilterChanged;
  final ValueChanged<StatusDateFilter> onDateFilterChanged;
  final ValueChanged<String?> onContactFilterChanged;
  final ValueChanged<String?> onCollectionFilterChanged;

  const _FilterBar({
    required this.filter,
    required this.dateFilter,
    required this.contactFilter,
    required this.collectionFilter,
    required this.collections,
    required this.onFilterChanged,
    required this.onDateFilterChanged,
    required this.onContactFilterChanged,
    required this.onCollectionFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _typeChip('All', StatusFilter.all),
          _typeChip('Images', StatusFilter.images),
          _typeChip('Videos', StatusFilter.videos),
          _typeChip('Favorites', StatusFilter.favorites),
          const SizedBox(width: 8),
          _dateChip('Today', StatusDateFilter.today),
          _dateChip('7 days', StatusDateFilter.last7Days),
          if (collections.isNotEmpty) ...[
            const SizedBox(width: 8),
            ...collections.map(
              (c) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(c),
                  selected: collectionFilter == c,
                  onSelected: (v) => onCollectionFilterChanged(v ? c : null),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Contact',
                prefixIcon: const Icon(Icons.person_search, size: 18),
                suffixIcon: contactFilter != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => onContactFilterChanged(null),
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onSubmitted: onContactFilterChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String label, StatusFilter value) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: filter == value,
        onSelected: (_) => onFilterChanged(value),
      ),
    );
  }

  Widget _dateChip(String label, StatusDateFilter value) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: dateFilter == value,
        onSelected: (v) => onDateFilterChanged(v ? value : StatusDateFilter.all),
      ),
    );
  }
}
