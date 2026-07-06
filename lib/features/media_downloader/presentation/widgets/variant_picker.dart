import 'package:flutter/material.dart';
import '../../data/models/media_variant.dart';
import '../../data/utils/download_format_utils.dart';

class VariantPicker extends StatelessWidget {
  final ResolvedMedia media;
  final Set<String> downloadingIds;
  final VoidCallback onBack;
  final void Function(MediaVariant variant) onDownload;
  final void Function(List<MediaVariant> variants) onDownloadAll;

  const VariantPicker({
    super.key,
    required this.media,
    required this.downloadingIds,
    required this.onBack,
    required this.onDownload,
    required this.onDownloadAll,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Material(
          color: cs.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
                Expanded(
                  child: Text(
                    'Choose format',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (media.videoVariants.isNotEmpty)
                  TextButton.icon(
                    onPressed: downloadingIds.isNotEmpty
                        ? null
                        : () => onDownloadAll([media.videoVariants.first]),
                    icon: const Icon(Icons.hd, size: 18),
                    label: const Text('Best video'),
                  ),
                if (media.audioVariants.isNotEmpty)
                  TextButton.icon(
                    onPressed: downloadingIds.isNotEmpty
                        ? null
                        : () => onDownloadAll([media.audioVariants.first]),
                    icon: const Icon(Icons.audiotrack, size: 18),
                    label: const Text('Audio'),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(media: media),
              const SizedBox(height: 16),
              _SummaryRow(media: media),
              const SizedBox(height: 20),
              if (media.videoVariants.isNotEmpty) ...[
                const _SectionTitle(icon: Icons.videocam_outlined, title: 'Video'),
                ...media.videoVariants.map((v) => _VariantTile(
                      variant: v,
                      isDownloading: downloadingIds.contains(v.id),
                      onDownload: () => onDownload(v),
                    )),
                const SizedBox(height: 16),
              ],
              if (media.audioVariants.isNotEmpty) ...[
                const _SectionTitle(icon: Icons.audiotrack_outlined, title: 'Audio'),
                ...media.audioVariants.map((v) => _VariantTile(
                      variant: v,
                      isDownloading: downloadingIds.contains(v.id),
                      onDownload: () => onDownload(v),
                    )),
                const SizedBox(height: 16),
              ],
              if (media.fileVariants.isNotEmpty) ...[
                const _SectionTitle(icon: Icons.insert_drive_file_outlined, title: 'Files'),
                ...media.fileVariants.map((v) => _VariantTile(
                      variant: v,
                      isDownloading: downloadingIds.contains(v.id),
                      onDownload: () => onDownload(v),
                    )),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final ResolvedMedia media;
  const _SummaryRow({required this.media});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Pill(label: '${media.videoVariants.length} video'),
        const SizedBox(width: 8),
        _Pill(label: '${media.audioVariants.length} audio'),
        const SizedBox(width: 8),
        _Pill(label: '${media.fileVariants.length} files'),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
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
              width: 110,
              height: 78,
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
              const SizedBox(height: 6),
              Chip(
                avatar: Icon(_platformIcon(media.platform), size: 16),
                label: Text(media.platform),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 110,
      height: 78,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.movie_outlined, size: 36),
    );
  }

  IconData _platformIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('youtube')) return Icons.play_circle_outline;
    if (p.contains('instagram')) return Icons.camera_alt_outlined;
    if (p.contains('tiktok')) return Icons.music_note;
    if (p.contains('facebook')) return Icons.facebook;
    return Icons.link;
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
            ? Text(formatBytes(variant.approxSizeBytes!))
            : null,
        trailing: isDownloading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : FilledButton.tonal(onPressed: onDownload, child: const Text('Save')),
      ),
    );
  }
}
