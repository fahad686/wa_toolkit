import '../models/media_variant.dart';
import 'page_resolver_utils.dart';

class PinterestResolver {
  static const _hosts = ['pinterest.com', 'pin.it'];
  static const _origin = 'https://www.pinterest.com';

  final PageResolverUtils _utils = PageResolverUtils();

  bool canHandle(String url) => _utils.hostMatches(url, _hosts);

  Future<ResolvedMedia> resolve(String url) async {
    final pageUrl = _resolvePinUrl(url);
    final html = await _utils.fetchHtml(pageUrl);
    final headers = _utils.cdnHeaders(pageUrl: pageUrl, origin: _origin);

    final variants = <MediaVariant>[];

    for (final m in RegExp(r'"url":"(https://[^"]+\.mp4[^"]*)"').allMatches(html)) {
      final videoUrl = PageResolverUtils.unescapeUrl(m.group(1)!);
      variants.add(MediaVariant(
        id: 'pin_${variants.length}',
        label: variants.isEmpty ? 'Video MP4' : 'Video MP4 #${variants.length + 1}',
        url: videoUrl,
        kind: MediaKind.video,
        container: 'mp4',
        headers: headers,
      ));
    }

    for (final def in [
      (key: 'V_720P', label: '720p'),
      (key: 'V_480P', label: '480p'),
      (key: 'V_EXP', label: 'Original'),
    ]) {
      final match = RegExp('"${def.key}":\\s*\\{[^}]*"url":"([^"]+)"').firstMatch(html);
      if (match != null) {
        final videoUrl = PageResolverUtils.unescapeUrl(match.group(1)!);
        variants.add(MediaVariant(
          id: 'pin_${def.key}',
          label: 'Video ${def.label}',
          url: videoUrl,
          kind: MediaKind.video,
          resolution: def.label,
          container: 'mp4',
          headers: headers,
        ));
      }
    }

    final og = _utils.ogVideo(html);
    if (variants.isEmpty && og != null) {
      variants.add(MediaVariant(
        id: 'pin_og',
        label: 'Video MP4',
        url: og,
        kind: MediaKind.video,
        container: 'mp4',
        headers: headers,
      ));
    }

    // Image pin fallback
    final imageUrl = _utils.ogImage(html);
    if (variants.isEmpty && imageUrl != null && !imageUrl.contains('.mp4')) {
      variants.add(MediaVariant(
        id: 'pin_image',
        label: 'Image',
        url: imageUrl,
        kind: MediaKind.file,
        container: 'jpg',
        headers: headers,
      ));
    }

    return _utils.buildResult(
      sourceUrl: pageUrl,
      platform: 'Pinterest',
      title: _utils.ogTitle(html) ?? _utils.pageTitle(html) ?? 'Pinterest pin',
      thumbnailUrl: imageUrl,
      variants: variants,
    );
  }

  String _resolvePinUrl(String input) {
    final url = _utils.normalizeUrl(input);
    if (url.contains('pin.it')) {
      return url;
    }
    return url;
  }
}
