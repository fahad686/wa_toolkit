import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/media_variant.dart';

class YoutubeResolver {
  final YoutubeExplode _yt = YoutubeExplode();

  bool canHandle(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        lower.contains('music.youtube.com');
  }

  Future<ResolvedMedia> resolve(String url) async {
    final video = await _yt.videos.get(url);
    final manifest = await _yt.videos.streamsClient.getManifest(video.id);
    final variants = <MediaVariant>[];

    for (final stream in manifest.muxed.sortByVideoQuality()) {
      final res = _resolutionLabel(stream.qualityLabel);
      variants.add(MediaVariant(
        id: 'muxed_${stream.tag}',
        label: '$res MP4 (with audio)',
        url: stream.url.toString(),
        kind: MediaKind.video,
        approxSizeBytes: stream.size.totalBytes,
        resolution: res,
        container: stream.container.name,
      ));
    }

    for (final stream in manifest.videoOnly.sortByVideoQuality()) {
      final res = _resolutionLabel(stream.qualityLabel);
      variants.add(MediaVariant(
        id: 'video_${stream.tag}',
        label: '$res MP4 (video only)',
        url: stream.url.toString(),
        kind: MediaKind.video,
        approxSizeBytes: stream.size.totalBytes,
        resolution: res,
        container: stream.container.name,
      ));
    }

    for (final stream in manifest.audioOnly.sortByBitrate()) {
      final kbps = stream.bitrate.kiloBitsPerSecond.round();
      variants.add(MediaVariant(
        id: 'audio_${stream.tag}',
        label: '$kbps kbps ${stream.container.name.toUpperCase()}',
        url: stream.url.toString(),
        kind: MediaKind.audio,
        approxSizeBytes: stream.size.totalBytes,
        container: stream.container.name,
        bitrateKbps: kbps,
      ));
    }

    if (variants.isEmpty) {
      throw StateError('No downloadable streams found for this video.');
    }

    return ResolvedMedia(
      sourceUrl: url,
      title: video.title,
      thumbnailUrl: video.thumbnails.highResUrl,
      platform: 'YouTube',
      variants: variants,
    );
  }

  String _resolutionLabel(String quality) {
    final q = quality.toLowerCase();
    if (q.contains('2160') || q.contains('4k')) return '4K';
    if (q.contains('1440') || q.contains('2k')) return '2K';
    if (q.contains('1080')) return '1080p';
    if (q.contains('720')) return '720p';
    if (q.contains('480')) return '480p';
    if (q.contains('360')) return '360p';
    if (q.contains('240')) return '240p';
    if (q.contains('144')) return '144p';
    return quality;
  }

  void dispose() => _yt.close();
}
