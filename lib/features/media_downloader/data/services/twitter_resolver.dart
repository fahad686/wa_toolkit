import '../models/media_variant.dart';
import 'page_resolver_utils.dart';

class TwitterResolver {
  static const _hosts = ['twitter.com', 'x.com', 'mobile.twitter.com', 'mobile.x.com'];
  static const _origin = 'https://x.com';

  final PageResolverUtils _utils = PageResolverUtils(userAgent: PageResolverUtils.desktopUserAgent);

  bool canHandle(String url) => _utils.hostMatches(url, _hosts);

  Future<ResolvedMedia> resolve(String url) async {
    final pageUrl = _utils.normalizeUrl(url);
    final html = await _utils.fetchHtml(pageUrl);
    final headers = _utils.cdnHeaders(pageUrl: pageUrl, origin: _origin);

    final variants = _extractTwitterVariants(html, pageUrl, headers);

    if (variants.isEmpty) {
      final fallback = _utils.ogVideo(html) ??
          _utils.firstMatch(html, [
            RegExp(r'"video_url":"([^"]+)"'),
            RegExp(r'"url":"(https://video[^"]+)"'),
          ]);
      if (fallback != null) {
        variants.add(MediaVariant(
          id: 'tw_video',
          label: 'Video MP4',
          url: fallback,
          kind: MediaKind.video,
          container: 'mp4',
          headers: headers,
          approxSizeBytes: await _utils.headSize(fallback, headers),
        ));
      }
    }

    return _utils.buildResult(
      sourceUrl: pageUrl,
      platform: 'X (Twitter)',
      title: _utils.ogTitle(html) ?? _utils.pageTitle(html) ?? 'X video',
      thumbnailUrl: _utils.ogImage(html),
      variants: variants,
    );
  }

  List<MediaVariant> _extractTwitterVariants(
    String html,
    String pageUrl,
    Map<String, String> headers,
  ) {
    final variants = <MediaVariant>[];
    final variantBlock = RegExp(r'"variants":\s*\[(.*?)\]', dotAll: true).firstMatch(html);
    if (variantBlock == null) return variants;

    final block = variantBlock.group(1)!;
    final urlMatches = RegExp(r'"url":"([^"]+)"').allMatches(block);
    final bitrateMatches = RegExp(r'"bitrate":(\d+)').allMatches(block).toList();

    var i = 0;
    for (final m in urlMatches) {
      final videoUrl = PageResolverUtils.unescapeUrl(m.group(1)!);
      if (!videoUrl.contains('video.twimg.com') && !videoUrl.endsWith('.mp4')) continue;

      final bitrate = i < bitrateMatches.length ? int.tryParse(bitrateMatches[i].group(1)!) : null;
      final label = bitrate != null ? 'Video ${(bitrate / 1000).round()} kbps' : 'Video MP4';

      variants.add(MediaVariant(
        id: 'tw_$i',
        label: label,
        url: videoUrl,
        kind: MediaKind.video,
        bitrateKbps: bitrate != null ? bitrate ~/ 1000 : null,
        container: 'mp4',
        headers: headers,
      ));
      i++;
    }

    variants.sort((a, b) => (b.bitrateKbps ?? 0).compareTo(a.bitrateKbps ?? 0));
    return variants;
  }
}
