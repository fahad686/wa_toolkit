import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/bootstrap.dart';
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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
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

  Future<void> _resolve() async {
    final input = _urlController.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _resolving = true;
      _error = null;
      _resolved = null;
    });

    try {
      final media = await AppServices.I.linkResolver.resolve(input);
      setState(() => _resolved = media);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _resolving = false);
    }
  }

  Future<void> _downloadVariant(MediaVariant variant) async {
    if (_resolved == null) return;
    setState(() => _downloadingVariantIds.add(variant.id));

    try {
      await AppServices.I.downloadManager.enqueue(
        sourceUrl: _resolved!.sourceUrl,
        title: _resolved!.title,
        variant: variant,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading ${variant.label}…')),
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
      if (mounted) setState(() => _downloadingVariantIds.remove(variant.id));
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = AppServices.I.downloadManager;
    final platform = AppServices.I.linkResolver.platformHint(_urlController.text);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Downloader'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
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
                child: const Icon(Icons.video_library_outlined),
              ),
              text: 'Videos',
            ),
            const Tab(icon: Icon(Icons.audiotrack_outlined), text: 'Audio'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _NewDownloadPane(
            urlController: _urlController,
            platform: platform,
            resolving: _resolving,
            error: _error,
            resolved: _resolved,
            downloadingIds: _downloadingVariantIds,
            onPaste: _pasteFromClipboard,
            onResolve: _resolve,
            onDownload: _downloadVariant,
          ),
          DownloadLibraryTab(manager: manager, activeOnly: true),
          DownloadLibraryTab(manager: manager, filter: MediaKind.video),
          DownloadLibraryTab(manager: manager, filter: MediaKind.audio),
        ],
      ),
    );
  }
}

class _NewDownloadPane extends StatelessWidget {
  final TextEditingController urlController;
  final String platform;
  final bool resolving;
  final String? error;
  final ResolvedMedia? resolved;
  final Set<String> downloadingIds;
  final VoidCallback onPaste;
  final VoidCallback onResolve;
  final void Function(MediaVariant) onDownload;

  const _NewDownloadPane({
    required this.urlController,
    required this.platform,
    required this.resolving,
    required this.error,
    required this.resolved,
    required this.downloadingIds,
    required this.onPaste,
    required this.onResolve,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    if (resolved != null) {
      return VariantPicker(
        media: resolved!,
        downloadingIds: downloadingIds,
        onDownload: onDownload,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Share a link from YouTube or any app — WA Toolkit will appear in the share menu.',
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
              hintText: 'https://youtube.com/watch?v=…',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste),
                onPressed: onPaste,
                tooltip: 'Paste',
              ),
            ),
            onSubmitted: (_) => onResolve(),
          ),
          if (urlController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(label: Text('Detected: $platform')),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: resolving ? null : onResolve,
            icon: resolving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search),
            label: Text(resolving ? 'Fetching formats…' : 'Get download options'),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: TextStyle(color: Colors.red.shade700)),
          ],
          const Spacer(),
          Text(
            'Supports YouTube (360p–4K, audio), direct file links, and HLS streams.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
