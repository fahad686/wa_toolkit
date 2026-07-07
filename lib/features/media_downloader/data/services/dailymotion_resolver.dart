import '../models/media_variant.dart';
import 'page_resolver_utils.dart';

class DailymotionResolver {
  static const _hosts = ['dailymotion.com', 'dai.ly'];
  static const _origin = 'https://www.dailymotion.com';

  final PageResolverUtils _utils = PageResolverUtils();

  bool canHandle(String url) => _utils.hostMatches(url, _hosts);

  Future<ResolvedMedia> resolve(String url) async {
    final pageUrl = _utils.normalizeUrl(url);
    final html = await _utils.fetchHtml(pageUrl);
    final headers = _utils.cdnHeaders(pageUrl: pageUrl, origin: _origin);
    final variants = <MediaVariant>[];

    for (final m in RegExp(r'"url":"(https://[^"]+\.mp4[^"]*)"').allMatches(html)) {
      final videoUrl = PageResolverUtils.unescapeUrl(m.group(1)!);
      if (!videoUrl.contains('dailymotion')) continue;
      variants.add(MediaVariant(
        id: 'dm_${variants.length}',
        label: variants.isEmpty ? 'Video MP4' : 'Video MP4 #${variants.length + 1}',
        url: videoUrl,
        kind: MediaKind.video,
        container: 'mp4',
        headers: headers,
      ));
    }

    for (final def in [
      (pattern: RegExp(r'"1080":\s*\{[^}]*"url":"([^"]+)"'), label: '1080p'),
      (pattern: RegExp(r'"720":\s*\{[^}]*"url":"([^"]+)"'), label: '720p'),
      (pattern: RegExp(r'"480":\s*\{[^}]*"url":"([^"]+)"'), label: '480p'),
      (pattern: RegExp(r'"380":\s*\{[^}]*"url":"([^"]+)"'), label: '360p'),
    ]) {
      final m = def.pattern.firstMatch(html);
      if (m == null) continue;
      final videoUrl = PageResolverUtils.unescapeUrl(m.group(1)!);
      variants.add(MediaVariant(
        id: 'dm_${def.label}',
        label: 'Video ${def.label}',
        url: videoUrl,
        kind: MediaKind.video,
        resolution: def.label,
        container: 'mp4',
        headers: headers,
      ));
    }

    if (variants.isEmpty) {
      final fallback = _utils.ogVideo(html) ??
          _utils.firstMatch(html, [RegExp(r'"qualities":\{[^}]*"auto":\[.*?"url":"([^"]+)"')]);
      if (fallback != null) {
        variants.add(MediaVariant(
          id: 'dm_auto',
          label: 'Video MP4',
          url: fallback,
          kind: MediaKind.video,
          container: 'mp4',
          headers: headers,
        ));
      }
    }

    return _utils.buildResult(
      sourceUrl: pageUrl,
      platform: 'Dailymotion',
      title: _utils.ogTitle(html) ?? _utils.pageTitle(html) ?? 'Dailymotion video',
      thumbnailUrl: _utils.ogImage(html),
      variants: variants,
    );
  }
}
