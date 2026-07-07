import '../models/media_variant.dart';
import 'page_resolver_utils.dart';

class FacebookResolver {
  static const _hosts = ['facebook.com', 'fb.watch', 'fb.com', 'm.facebook.com'];
  static const _origin = 'https://www.facebook.com';

  final PageResolverUtils _utils = PageResolverUtils(userAgent: PageResolverUtils.desktopUserAgent);

  bool canHandle(String url) => _utils.hostMatches(url, _hosts);

  Future<ResolvedMedia> resolve(String url) async {
    final pageUrl = _utils.normalizeUrl(url);
    final html = await _utils.fetchHtml(pageUrl);

    final variants = <MediaVariant>[];
    final headers = _utils.cdnHeaders(pageUrl: pageUrl, origin: _origin);

    final hd = _utils.firstMatch(html, [RegExp(r'"browser_native_hd_url":"([^"]+)"')]);
    final sd = _utils.firstMatch(html, [RegExp(r'"browser_native_sd_url":"([^"]+)"')]);
    final og = _utils.ogVideo(html);

    if (hd != null) {
      variants.add(MediaVariant(
        id: 'fb_hd',
        label: 'Video HD',
        url: hd,
        kind: MediaKind.video,
        resolution: '720p',
        container: 'mp4',
        headers: headers,
        approxSizeBytes: await _utils.headSize(hd, headers),
      ));
    }
    if (sd != null && sd != hd) {
      variants.add(MediaVariant(
        id: 'fb_sd',
        label: 'Video SD',
        url: sd,
        kind: MediaKind.video,
        resolution: '480p',
        container: 'mp4',
        headers: headers,
        approxSizeBytes: await _utils.headSize(sd, headers),
      ));
    }
    if (variants.isEmpty && og != null) {
      variants.add(MediaVariant(
        id: 'fb_og',
        label: 'Video MP4',
        url: og,
        kind: MediaKind.video,
        resolution: 'Original',
        container: 'mp4',
        headers: headers,
        approxSizeBytes: await _utils.headSize(og, headers),
      ));
    }

    return _utils.buildResult(
      sourceUrl: pageUrl,
      platform: 'Facebook',
      title: _utils.ogTitle(html) ?? _utils.pageTitle(html) ?? 'Facebook video',
      thumbnailUrl: _utils.ogImage(html),
      variants: variants,
    );
  }
}
