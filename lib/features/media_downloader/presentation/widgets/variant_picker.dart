import 'package:flutter/material.dart';
import '../../data/models/media_variant.dart';

class VariantPicker extends StatelessWidget {
  final ResolvedMedia media;
  final Set<String> downloadingIds;
  final void Function(MediaVariant variant) onDownload;

  const VariantPicker({
    super.key,
    required this.media,
    required this.downloadingIds,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(media: media),
        const SizedBox(height: 20),
        if (media.videoVariants.isNotEmpty) ...[
          _SectionTitle(icon: Icons.videocam_outlined, title: 'Video'),
          ...media.videoVariants.map((v) => _VariantTile(
                variant: v,
                isDownloading: downloadingIds.contains(v.id),
                onDownload: () => onDownload(v),
              )),
          const SizedBox(height: 16),
        ],
        if (media.audioVariants.isNotEmpty) ...[
          _SectionTitle(icon: Icons.audiotrack_outlined, title: 'Audio'),
          ...media.audioVariants.map((v) => _VariantTile(
                variant: v,
                isDownloading: downloadingIds.contains(v.id),
                onDownload: () => onDownload(v),
              )),
          const SizedBox(height: 16),
        ],
        if (media.fileVariants.isNotEmpty) ...[
          _SectionTitle(icon: Icons.insert_drive_file_outlined, title: 'Files'),
          ...media.fileVariants.map((v) => _VariantTile(
                variant: v,
                isDownloading: downloadingIds.contains(v.id),
                onDownload: () => onDownload(v),
              )),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final ResolvedMedia media;
  const _Header({required this.media});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (media.thumbnailUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              media.thumbnailUrl!,
              width: 96,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _thumbPlaceholder(),
            ),
          )
        else
          _thumbPlaceholder(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(media.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Chip(
                label: Text(media.platform, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 96,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.movie_outlined),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _VariantTile extends StatelessWidget {
  final MediaVariant variant;
  final bool isDownloading;
  final VoidCallback onDownload;

  const _VariantTile({
    required this.variant,
    required this.isDownloading,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: switch (variant.kind) {
            MediaKind.video => cs.primaryContainer,
            MediaKind.audio => Colors.orange.shade100,
            MediaKind.file => Colors.blueGrey.shade100,
          },
          child: Icon(
            switch (variant.kind) {
              MediaKind.video => Icons.videocam,
              MediaKind.audio => Icons.audiotrack,
              MediaKind.file => Icons.insert_drive_file,
            },
            size: 20,
          ),
        ),
        title: Text(variant.label),
        subtitle: variant.approxSizeBytes != null
            ? Text(_formatBytes(variant.approxSizeBytes!))
            : null,
        trailing: isDownloading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : FilledButton.tonal(
                onPressed: onDownload,
                child: const Text('Save'),
              ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
