import '../models/media_variant.dart';
import 'page_resolver_utils.dart';

class SnapchatResolver {
  static const _hosts = ['snapchat.com', 'story.snapchat.com'];
  static const _origin = 'https://www.snapchat.com';

  final PageResolverUtils _utils = PageResolverUtils();

  bool canHandle(String url) => _utils.hostMatches(url, _hosts);

  Future<ResolvedMedia> resolve(String url) async {
    final pageUrl = _utils.normalizeUrl(url);
    final html = await _utils.fetchHtml(pageUrl);

    final videoUrl = _utils.ogVideo(html) ??
        _utils.firstMatch(html, [
          RegExp(r'"mediaUrl":"([^"]+)"'),
          RegExp(r'"snapMediaUrl":"([^"]+)"'),
          RegExp(r'"contentUrl":"(https://[^"]+\.mp4[^"]*)"'),
          RegExp(r'"playbackUrl":"([^"]+)"'),
        ]);

    if (videoUrl == null) {
      throw StateError(
        'Could not extract Snapchat media. Spotlight/story links often expire or require the app.',
      );
    }

    final headers = _utils.cdnHeaders(pageUrl: pageUrl, origin: _origin);
    return _utils.buildResult(
      sourceUrl: pageUrl,
      platform: 'Snapchat',
      title: _utils.ogTitle(html) ?? _utils.pageTitle(html) ?? 'Snapchat media',
      thumbnailUrl: _utils.ogImage(html),
      variants: [
        MediaVariant(
          id: 'snap_video',
          label: 'Video MP4',
          url: videoUrl,
          kind: MediaKind.video,
          container: 'mp4',
          headers: headers,
          approxSizeBytes: await _utils.headSize(videoUrl, headers),
        ),
      ],
    );
  }
}
