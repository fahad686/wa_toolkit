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
      _items = widget.cache.filter(_filter, variant: widget.variant);
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusViewerScreen(
          item: item,
          cache: widget.cache,
          gallery: widget.gallery,
          share: widget.share,
          repair: widget.repair,
          onChanged: _refreshList,
        ),
      ),
    );
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
          onRefresh: () => _scan(),
          onShowGuide: () => _showGuideSheet(),
          onRegrant: _grantAccess,
        ),
        _FilterBar(
          filter: _filter,
          onFilterChanged: (f) async {
            setState(() => _filter = f);
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
  final VoidCallback onRefresh;
  final VoidCallback onShowGuide;
  final VoidCallback onRegrant;

  const _TopBar({
    required this.variant,
    required this.loading,
    required this.missingCount,
    required this.onRefresh,
    required this.onShowGuide,
    required this.onRegrant,
  });

  @override
  Widget build(BuildContext context) {
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
  final ValueChanged<StatusFilter> onFilterChanged;

  const _FilterBar({required this.filter, required this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _chip('All', StatusFilter.all),
          _chip('Images', StatusFilter.images),
          _chip('Videos', StatusFilter.videos),
        ],
      ),
    );
  }

  Widget _chip(String label, StatusFilter value) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: filter == value,
        onSelected: (_) => onFilterChanged(value),
      ),
    );
  }
}
