enum MediaKind { video, audio, file }

/// One downloadable rendition — e.g. 720p MP4, 128kbps audio.
class MediaVariant {
  final String id;
  final String label;
  final String url;
  final MediaKind kind;
  final int? approxSizeBytes;
  final String? resolution;
  final String? container;
  final int? bitrateKbps;
  final bool requiresMerge;

  const MediaVariant({
    required this.id,
    required this.label,
    required this.url,
    required this.kind,
    this.approxSizeBytes,
    this.resolution,
    this.container,
    this.bitrateKbps,
    this.requiresMerge = false,
  });

  int get sortOrder {
    final res = resolution?.toLowerCase() ?? '';
    if (res.contains('4k') || res.contains('2160')) return 600;
    if (res.contains('2k') || res.contains('1440')) return 500;
    if (res.contains('1080')) return 400;
    if (res.contains('720')) return 300;
    if (res.contains('480')) return 200;
    if (res.contains('360')) return 100;
    if (kind == MediaKind.audio) return (bitrateKbps ?? 0);
    return 0;
  }
}

class ResolvedMedia {
  final String sourceUrl;
  final String title;
  final String? thumbnailUrl;
  final String platform;
  final List<MediaVariant> variants;

  const ResolvedMedia({
    required this.sourceUrl,
    required this.title,
    this.thumbnailUrl,
    required this.platform,
    required this.variants,
  });

  List<MediaVariant> get videoVariants =>
      variants.where((v) => v.kind == MediaKind.video).toList()
        ..sort((a, b) => b.sortOrder.compareTo(a.sortOrder));

  List<MediaVariant> get audioVariants =>
      variants.where((v) => v.kind == MediaKind.audio).toList()
        ..sort((a, b) => b.sortOrder.compareTo(a.sortOrder));

  List<MediaVariant> get fileVariants =>
      variants.where((v) => v.kind == MediaKind.file).toList();
}
