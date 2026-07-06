import 'package:flutter/material.dart';
import '../services/downloader_service.dart';

class DownloaderTab extends StatefulWidget {
  final DownloaderService downloader;
  const DownloaderTab({super.key, required this.downloader});

  @override
  State<DownloaderTab> createState() => _DownloaderTabState();
}

class _DownloaderTabState extends State<DownloaderTab> {
  final _urlController = TextEditingController();
  List<MediaVariant> _variants = [];
  bool _resolving = false;
  String? _error;
  MediaVariant? _downloading;
  double _progress = 0;

  Future<void> _resolve() async {
    setState(() {
      _resolving = true;
      _error = null;
      _variants = [];
    });
    try {
      final variants = await widget.downloader.resolveVariants(_urlController.text.trim());
      setState(() => _variants = variants);
    } catch (e) {
      setState(() => _error = 'Could not resolve link: $e');
    } finally {
      setState(() => _resolving = false);
    }
  }

  Future<void> _download(MediaVariant variant) async {
    setState(() {
      _downloading = variant;
      _progress = 0;
    });
    try {
      final path = await widget.downloader.download(
        variant,
        onProgress: (p) => setState(() => _progress = p.fraction),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Saved to $path')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    } finally {
      setState(() => _downloading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Paste a direct media link',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _resolving ? null : _resolve,
            child: _resolving
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Find available variants'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _variants.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final v = _variants[index];
                final isDownloadingThis = _downloading == v;
                return ListTile(
                  leading: Icon(switch (v.kind) {
                    MediaKind.video => Icons.videocam,
                    MediaKind.audio => Icons.audiotrack,
                    MediaKind.file => Icons.insert_drive_file,
                  }),
                  title: Text(v.label),
                  subtitle: v.approxSizeBytes != null
                      ? Text(_formatBytes(v.approxSizeBytes!))
                      : null,
                  trailing: isDownloadingThis
                      ? SizedBox(
                          width: 40,
                          child: CircularProgressIndicator(value: _progress),
                        )
                      : IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: _downloading == null ? () => _download(v) : null,
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
