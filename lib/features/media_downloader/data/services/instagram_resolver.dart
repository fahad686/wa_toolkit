import 'package:dio/dio.dart';
import '../models/media_variant.dart';
import 'page_resolver_utils.dart';

/// Resolves Instagram reels/posts by extracting the CDN video URL from page HTML.
class InstagramResolver {
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  final Dio _dio = Dio(BaseOptions(
    headers: {
      'User-Agent': _userAgent,
      'Accept': 'text/html,application/xhtml+xml',
      'Accept-Language': 'en-US,en;q=0.9',
    },
    followRedirects: true,
    validateStatus: (s) => s != null && s < 500,
  ));

  bool canHandle(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.contains('instagram.com');
  }

  Future<ResolvedMedia> resolve(String url) async {
    final pageUrl = _normalizeUrl(url);
    final response = await _dio.get<String>(pageUrl);
    final html = response.data ?? '';

    if (html.isEmpty) {
      throw StateError('Instagram returned an empty page. Try opening the link in a browser first.');
    }

    final videoUrl = _extractVideoUrl(html);
    if (videoUrl == null) {
      throw StateError(
        'Could not extract video from this Instagram link. '
        'The post may be private, age-restricted, or require login.',
      );
    }

    final title = _extractTitle(html) ?? 'Instagram video';
    final thumbnail = _extractThumbnail(html);
    int? size;

    try {
      final head = await _dio.head(
        videoUrl,
        options: Options(
          headers: _cdnHeaders(pageUrl),
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      size = int.tryParse(head.headers.value('content-length') ?? '');
    } catch (_) {}

    return ResolvedMedia(
      sourceUrl: pageUrl,
      title: title,
      thumbnailUrl: thumbnail,
      platform: 'Instagram',
      variants: [
        MediaVariant(
          id: 'ig_video_hd',
          label: 'Video MP4 (best quality)',
          url: videoUrl,
          kind: MediaKind.video,
          approxSizeBytes: size,
          resolution: 'Original',
          container: 'mp4',
          headers: _cdnHeaders(pageUrl),
        ),
      ],
    );
  }

  String _normalizeUrl(String url) {
    final uri = Uri.parse(extractUrlFromText(url) ?? url.trim());
    var path = uri.path;
    if (path.endsWith('/')) path = path.substring(0, path.length - 1);
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      path: path,
    ).toString();
  }

  Map<String, String> _cdnHeaders(String pageUrl) => {
        'User-Agent': _userAgent,
        'Referer': pageUrl,
        'Origin': 'https://www.instagram.com',
      };

  String? _extractVideoUrl(String html) {
    final patterns = [
      RegExp(r'"video_url":"([^"]+)"'),
      RegExp(r'"videoUrl":"([^"]+)"'),
      RegExp(r'property="og:video:secure_url" content="([^"]+)"'),
      RegExp(r'property="og:video" content="([^"]+)"'),
      RegExp(r'"contentUrl":"(https://[^"]+\.mp4[^"]*)"'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match == null) continue;
      final raw = match.group(1)!;
      final decoded = _unescapeJsonUrl(raw);
      if (decoded.startsWith('http') && !decoded.contains('instagram.com/reel')) {
        return decoded;
      }
    }
    return null;
  }

  String? _extractTitle(String html) {
    final og = RegExp(r'property="og:title" content="([^"]+)"').firstMatch(html);
    if (og != null) return _decodeHtmlEntities(og.group(1)!);

    final title = RegExp(r'<title>([^<]+)</title>').firstMatch(html);
    return title?.group(1)?.replaceAll(' • Instagram', '').trim();
  }

  String? _extractThumbnail(String html) {
    final og = RegExp(r'property="og:image" content="([^"]+)"').firstMatch(html);
    return og?.group(1);
  }

  String _unescapeJsonUrl(String raw) {
    return raw
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\/', '/')
        .replaceAll(r'\\u0026', '&');
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}
