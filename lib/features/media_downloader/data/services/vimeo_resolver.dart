import 'dart:convert';
import '../models/media_variant.dart';
import 'page_resolver_utils.dart';

class VimeoResolver {
  static const _hosts = ['vimeo.com', 'player.vimeo.com'];
  static const _origin = 'https://vimeo.com';

  final PageResolverUtils _utils = PageResolverUtils();

  bool canHandle(String url) => _utils.hostMatches(url, _hosts);

  Future<ResolvedMedia> resolve(String url) async {
    final pageUrl = _utils.normalizeUrl(url);
    final html = await _utils.fetchHtml(pageUrl);
    final headers = _utils.cdnHeaders(pageUrl: pageUrl, origin: _origin);
    final variants = <MediaVariant>[];

    // Progressive renditions from player config JSON embedded in page.
    final configMatch = RegExp(r'window\.playerConfig\s*=\s*(\{.+?\})\s*;').firstMatch(html) ??
        RegExp(r'"progressive":\s*(\[[^\]]+\])').firstMatch(html);

    if (configMatch != null) {
      try {
        final raw = configMatch.group(1)!;
        if (raw.startsWith('[')) {
          final list = jsonDecode(raw) as List;
          for (final item in list) {
            if (item is! Map) continue;
            final videoUrl = item['url'] as String?;
            final height = item['height'] as int?;
            if (videoUrl == null) continue;
            variants.add(MediaVariant(
              id: 'vimeo_${height ?? variants.length}',
              label: height != null ? '${height}p MP4' : 'Video MP4',
              url: videoUrl,
              kind: MediaKind.video,
              resolution: height != null ? '${height}p' : 'Original',
              container: 'mp4',
              headers: headers,
            ));
          }
        } else {
          final config = jsonDecode(raw) as Map<String, dynamic>;
          final progressive = _dig<List>(config, ['request', 'files', 'progressive']) ??
              _dig<List>(config, ['video', 'progressive']);
          if (progressive != null) {
            for (final item in progressive) {
              if (item is! Map) continue;
              final videoUrl = item['url'] as String?;
              final height = item['height'] as int?;
              if (videoUrl == null) continue;
              variants.add(MediaVariant(
                id: 'vimeo_${height ?? variants.length}',
                label: height != null ? '${height}p MP4' : 'Video MP4',
                url: videoUrl,
                kind: MediaKind.video,
                resolution: height != null ? '${height}p' : 'Original',
                container: 'mp4',
                headers: headers,
              ));
            }
          }
        }
      } catch (_) {}
    }

    if (variants.isEmpty) {
      final fallback = _utils.ogVideo(html) ??
          _utils.firstMatch(html, [
            RegExp(r'"progressive":\s*\[\{[^}]*"url":"([^"]+)"'),
            RegExp(r'"url":"(https://[^"]*vimeocdn[^"]+\.mp4[^"]*)"'),
          ]);
      if (fallback != null) {
        variants.add(MediaVariant(
          id: 'vimeo_fallback',
          label: 'Video MP4',
          url: fallback,
          kind: MediaKind.video,
          container: 'mp4',
          headers: headers,
        ));
      }
    }

    variants.sort((a, b) => b.sortOrder.compareTo(a.sortOrder));

    return _utils.buildResult(
      sourceUrl: pageUrl,
      platform: 'Vimeo',
      title: _utils.ogTitle(html) ?? _utils.pageTitle(html) ?? 'Vimeo video',
      thumbnailUrl: _utils.ogImage(html),
      variants: variants,
    );
  }

  T? _dig<T>(Map<String, dynamic> map, List<String> keys) {
    dynamic cur = map;
    for (final k in keys) {
      if (cur is! Map) return null;
      cur = cur[k];
    }
    return cur is T ? cur : null;
  }
}
