import 'package:dio/dio.dart';
import '../models/media_variant.dart';

class HlsResolver {
  final Dio _dio = Dio();

  bool canHandle(String url) => url.toLowerCase().contains('.m3u8');

  Future<ResolvedMedia?> resolve(String url) async {
    final response = await _dio.get<String>(url);
    final body = response.data ?? '';
    if (!body.contains('#EXTM3U')) return null;

    final variants = <MediaVariant>[];
    final lines = body.split('\n');
    var index = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;

      final resolution = _extractAttr(line, 'RESOLUTION');
      final bandwidth = int.tryParse(_extractAttr(line, 'BANDWIDTH') ?? '');
      final nextLine = i + 1 < lines.length ? lines[i + 1].trim() : '';
      if (nextLine.isEmpty || nextLine.startsWith('#')) continue;

      final streamUrl = _resolveUrl(url, nextLine);
      final resLabel = resolution != null ? _formatResolution(resolution) : _bandwidthLabel(bandwidth);
      final approxSize = bandwidth != null ? (bandwidth ~/ 8) * 60 : null;

      variants.add(MediaVariant(
        id: 'hls_$index',
        label: '$resLabel HLS',
        url: streamUrl,
        kind: MediaKind.video,
        approxSizeBytes: approxSize,
        resolution: resLabel,
        container: 'm3u8',
      ));
      index++;
    }

    if (variants.isEmpty) {
      variants.add(MediaVariant(
        id: 'hls_master',
        label: 'HLS stream',
        url: url,
        kind: MediaKind.video,
        container: 'm3u8',
      ));
    }

    variants.sort((a, b) => b.sortOrder.compareTo(a.sortOrder));

    return ResolvedMedia(
      sourceUrl: url,
      title: Uri.parse(url).pathSegments.lastWhere(
            (s) => s.isNotEmpty,
            orElse: () => 'HLS stream',
          ),
      platform: 'HLS',
      variants: variants,
    );
  }

  String? _extractAttr(String line, String key) {
    final match = RegExp('$key=([^,]+)').firstMatch(line);
    return match?.group(1)?.replaceAll('"', '');
  }

  String _formatResolution(String res) {
    final parts = res.split('x');
    if (parts.length == 2) {
      final h = int.tryParse(parts[1]) ?? 0;
      if (h >= 2160) return '4K';
      if (h >= 1440) return '2K';
      if (h >= 1080) return '1080p';
      if (h >= 720) return '720p';
      if (h >= 480) return '480p';
      if (h >= 360) return '360p';
      return '${parts[1]}p';
    }
    return res;
  }

  String _bandwidthLabel(int? bps) {
    if (bps == null) return 'Auto';
    final mbps = bps / 1000000;
    if (mbps >= 1) return '${mbps.toStringAsFixed(1)} Mbps';
    return '${(bps / 1000).round()} kbps';
  }

  String _resolveUrl(String base, String relative) {
    if (relative.startsWith('http')) return relative;
    final uri = Uri.parse(base);
    if (relative.startsWith('/')) {
      return '${uri.scheme}://${uri.host}$relative';
    }
    final basePath = uri.path.substring(0, uri.path.lastIndexOf('/') + 1);
    return '${uri.scheme}://${uri.host}$basePath$relative';
  }
}
