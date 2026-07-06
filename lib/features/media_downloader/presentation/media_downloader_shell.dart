import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/bootstrap.dart';
import '../../../widgets/animated_loading_overlay.dart';
import '../data/models/media_variant.dart';
import 'widgets/download_library_tab.dart';
import 'widgets/variant_picker.dart';

class MediaDownloaderShell extends StatefulWidget {
  final String? initialUrl;

  const MediaDownloaderShell({super.key, this.initialUrl});

  @override
  State<MediaDownloaderShell> createState() => _MediaDownloaderShellState();
}

class _MediaDownloaderShellState extends State<MediaDownloaderShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _urlController = TextEditingController();
  ResolvedMedia? _resolved;
  bool _resolving = false;
  String? _error;
  final Set<String> _downloadingVariantIds = {};
  List<String> _recentUrls = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _recentUrls = AppServices.I.prefs.recentDownloadUrls;
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoPaste());
    }
    AppServices.I.downloadManager.addListener(_onManagerUpdate);
  }

  @override
  void dispose() {
    AppServices.I.downloadManager.removeListener(_onManagerUpdate);
    _tabs.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _onManagerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _tryAutoPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.startsWith('http') && _urlController.text.isEmpty && mounted) {
      _urlController.text = text;
      setState(() {});
    }
  }

  Future<void> _resolve() async {
    final input = _urlController.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _resolving = true;
      _error = null;
      _resolved = null;
    });

    final platform = AppServices.I.linkResolver.platformHint(input);
    if (mounted) {
      AnimatedLoadingOverlay.show(
        context,
        message: 'Fetching download options',
        subtitle: platform == 'Direct link' ? 'Resolving link…' : 'From $platform',
        icon: Icons.travel_explore_rounded,
      );
    }

    try {
      final media = await AppServices.I.linkResolver.resolve(input);
      await AppServices.I.prefs.addRecentDownloadUrl(input);
      _recentUrls = AppServices.I.prefs.recentDownloadUrls;
      if (mounted) setState(() => _resolved = media);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('StateError: ', ''));
    } finally {
      AnimatedLoadingOverlay.hide();
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _clearResolved() => setState(() {
        _resolved = null;
        _error = null;
      });

  Future<void> _downloadVariant(MediaVariant variant) async {
    if (_resolved == null) return;
    await _downloadVariants([variant]);
  }

  Future<void> _downloadVariants(List<MediaVariant> variants) async {
    if (_resolved == null || variants.isEmpty) return;

    setState(() => _downloadingVariantIds.addAll(variants.map((v) => v.id)));

    if (mounted) {
      AnimatedLoadingOverlay.show(
        context,
        message: variants.length == 1 ? 'Starting download' : 'Queuing downloads',
        subtitle: _resolved!.title,
        icon: Icons.download_rounded,
      );
    }

    try {
      for (final variant in variants) {
        await AppServices.I.downloadManager.enqueue(
          sourceUrl: _resolved!.sourceUrl,
          title: _resolved!.title,
          platform: _resolved!.platform,
          variant: variant,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              variants.length == 1
                  ? 'Downloading ${variants.first.label}…'
                  : 'Queued ${variants.length} downloads',
            ),
          ),
        );
        _tabs.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      AnimatedLoadingOverlay.hide();
      if (mounted) {
        setState(() => _downloadingVariantIds.removeAll(variants.map((v) => v.id)));
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
      setState(() {});
    }
  }

  Future<void> _clearCompleted() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear completed downloads?'),
        content: const Text('This removes completed items from the list and deletes their files.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirm == true) {
      if (mounted) {
        AnimatedLoadingOverlay.show(
          context,
          message: 'Clearing downloads',
          icon: Icons.cleaning_services_outlined,
        );
      }
      try {
        await AppServices.I.downloadManager.clearCompleted();
      } finally {
        AnimatedLoadingOverlay.hide();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = AppServices.I.downloadManager;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Downloader'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'alerts') {
                final enabled = !AppServices.I.prefs.downloadAlertsEnabled;
                await AppServices.I.prefs.setDownloadAlertsEnabled(enabled);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(enabled ? 'Download alerts on' : 'Download alerts off')),
                  );
                  setState(() {});
                }
              } else if (value == 'clear') {
                await _clearCompleted();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'alerts',
                child: Row(
                  children: [
                    Icon(AppServices.I.prefs.downloadAlertsEnabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined),
                    const SizedBox(width: 12),
                    Text(AppServices.I.prefs.downloadAlertsEnabled
                        ? 'Download alerts on'
                        : 'Download alerts off'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                enabled: manager.completed.isNotEmpty,
                child: const Row(
                  children: [
                    Icon(Icons.cleaning_services_outlined),
                    SizedBox(width: 12),
                    Text('Clear completed'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            const Tab(icon: Icon(Icons.link), text: 'New'),
            Tab(
              icon: Badge(
                isLabelVisible: manager.active.isNotEmpty,
                label: Text('${manager.active.length}'),
                child: const Icon(Icons.downloading),
              ),
              text: 'Active',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: manager.completedCount > 0,
                label: Text('${manager.completedCount}'),
                child: const Icon(Icons.folder_outlined),
              ),
              text: 'Downloads',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _NewDownloadPane(
            urlController: _urlController,
            resolving: _resolving,
            error: _error,
            resolved: _resolved,
            recentUrls: _recentUrls,
            downloadingIds: _downloadingVariantIds,
            onPaste: _pasteFromClipboard,
            onResolve: _resolve,
            onClearResolved: _clearResolved,
            onDownload: _downloadVariant,
            onDownloadAll: _downloadVariants,
            onRecentTap: (url) {
              _urlController.text = url;
              _resolve();
            },
          ),
          DownloadLibraryTab(manager: manager, activeOnly: true),
          DownloadLibraryTab(manager: manager),
        ],
      ),
    );
  }
}

class _NewDownloadPane extends StatefulWidget {
  final TextEditingController urlController;
  final bool resolving;
  final String? error;
  final ResolvedMedia? resolved;
  final List<String> recentUrls;
  final Set<String> downloadingIds;
  final VoidCallback onPaste;
  final VoidCallback onResolve;
  final VoidCallback onClearResolved;
  final void Function(MediaVariant) onDownload;
  final void Function(List<MediaVariant>) onDownloadAll;
  final void Function(String url) onRecentTap;

  const _NewDownloadPane({
    required this.urlController,
    required this.resolving,
    required this.error,
    required this.resolved,
    required this.recentUrls,
    required this.downloadingIds,
    required this.onPaste,
    required this.onResolve,
    required this.onClearResolved,
    required this.onDownload,
    required this.onDownloadAll,
    required this.onRecentTap,
  });

  @override
  State<_NewDownloadPane> createState() => _NewDownloadPaneState();
}

class _NewDownloadPaneState extends State<_NewDownloadPane> {
  @override
  void initState() {
    super.initState();
    widget.urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    widget.urlController.removeListener(_onUrlChanged);
    super.dispose();
  }

  void _onUrlChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (widget.resolved != null) {
      return VariantPicker(
        media: widget.resolved!,
        downloadingIds: widget.downloadingIds,
        onBack: widget.onClearResolved,
        onDownload: widget.onDownload,
        onDownloadAll: widget.onDownloadAll,
      );
    }

    final urlController = widget.urlController;
    final platform = AppServices.I.linkResolver.platformHint(urlController.text);
    final resolving = widget.resolving;
    final error = widget.error;
    final recentUrls = widget.recentUrls;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.ios_share, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Share any link from YouTube, Instagram, TikTok, etc. — WA Toolkit appears in the share menu.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: urlController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Paste link here',
            hintText: 'https://…',
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (urlController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => urlController.clear(),
                  ),
                IconButton(
                  icon: const Icon(Icons.content_paste),
                  onPressed: widget.onPaste,
                  tooltip: 'Paste',
                ),
              ],
            ),
          ),
          onChanged: (_) {},
          onSubmitted: (_) => widget.onResolve(),
        ),
        if (urlController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: const Icon(Icons.sensors, size: 16),
              label: Text('Detected: $platform'),
            ),
          ),
        ],
        if (recentUrls.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Recent links', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recentUrls.map((url) {
              final short = Uri.tryParse(url)?.host ?? url;
              return ActionChip(
                label: Text(short, overflow: TextOverflow.ellipsis),
                onPressed: () => widget.onRecentTap(url),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: resolving ? null : widget.onResolve,
          icon: resolving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.search),
          label: Text(resolving ? 'Fetching formats…' : 'Get download options'),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 10),
                  Expanded(child: Text(error!, style: TextStyle(color: Colors.red.shade800))),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Supported platforms',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _PlatformChip('YouTube'),
            _PlatformChip('Instagram'),
            _PlatformChip('TikTok'),
            _PlatformChip('Facebook'),
            _PlatformChip('X'),
            _PlatformChip('Pinterest'),
            _PlatformChip('Vimeo'),
            _PlatformChip('Dailymotion'),
            _PlatformChip('Direct links'),
            _PlatformChip('HLS'),
          ],
        ),
      ],
    );
  }
}

class _PlatformChip extends StatelessWidget {
  final String label;
  const _PlatformChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
