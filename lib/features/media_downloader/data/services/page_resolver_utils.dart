import 'package:dio/dio.dart';
import '../models/media_variant.dart';

/// Shared HTTP + HTML helpers for social / embed page resolvers.
class PageResolverUtils {
  static const mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 13; SM-G991B) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static const desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final Dio dio;

  PageResolverUtils({String? userAgent})
      : dio = Dio(BaseOptions(
          headers: {
            'User-Agent': userAgent ?? mobileUserAgent,
            'Accept': 'text/html,application/xhtml+xml,application/json',
            'Accept-Language': 'en-US,en;q=0.9',
          },
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ));

  Future<String> fetchHtml(String url) async {
    final response = await dio.get<String>(url);
    return response.data ?? '';
  }

  Map<String, String> cdnHeaders({required String pageUrl, required String origin}) => {
        'User-Agent': mobileUserAgent,
        'Referer': pageUrl,
        'Origin': origin,
      };

  String normalizeUrl(String input) {
    final raw = extractUrlFromText(input) ?? input.trim();
    final uri = Uri.parse(raw);
    var path = uri.path;
    if (path.endsWith('/')) path = path.substring(0, path.length - 1);
    return Uri(scheme: uri.scheme, host: uri.host, path: path).toString();
  }

  bool hostMatches(String url, List<String> hosts) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return hosts.any((h) => host.contains(h));
  }

  ResolvedMedia buildResult({
    required String sourceUrl,
    required String platform,
    required String title,
    required List<MediaVariant> variants,
    String? thumbnailUrl,
  }) {
    if (variants.isEmpty) {
      throw StateError('No downloadable media found for this $platform link.');
    }
    return ResolvedMedia(
      sourceUrl: sourceUrl,
      title: title,
      thumbnailUrl: thumbnailUrl,
      platform: platform,
      variants: variants,
    );
  }

  String? ogVideo(String html) {
    for (final pattern in [
      RegExp(r'property="og:video:secure_url" content="([^"]+)"'),
      RegExp(r'property="og:video" content="([^"]+)"'),
      RegExp(r'property="og:video:url" content="([^"]+)"'),
    ]) {
      final m = pattern.firstMatch(html);
      if (m != null) return unescapeUrl(m.group(1)!);
    }
    return null;
  }

  String? ogTitle(String html) {
    final raw = RegExp(r'property="og:title" content="([^"]+)"').firstMatch(html)?.group(1);
    return raw != null ? decodeHtmlEntities(raw) : null;
  }

  String? ogImage(String html) =>
      RegExp(r'property="og:image" content="([^"]+)"').firstMatch(html)?.group(1);

  String? pageTitle(String html) =>
      RegExp(r'<title>([^<]+)</title>', caseSensitive: false).firstMatch(html)?.group(1)?.trim();

  String? firstMatch(String html, List<RegExp> patterns) {
    for (final p in patterns) {
      final m = p.firstMatch(html);
      if (m == null) continue;
      final url = unescapeUrl(m.group(1)!);
      if (url.startsWith('http')) return url;
    }
    return null;
  }

  List<MediaVariant> variantsFromPatterns(
    String html,
    List<({RegExp pattern, String label, String id})> defs, {
    required String pageUrl,
    required String origin,
    MediaKind kind = MediaKind.video,
  }) {
    final found = <String, MediaVariant>{};
    for (final d in defs) {
      for (final m in d.pattern.allMatches(html)) {
        final url = unescapeUrl(m.group(1)!);
        if (!url.startsWith('http')) continue;
        found.putIfAbsent(
          url,
          () => MediaVariant(
            id: d.id,
            label: d.label,
            url: url,
            kind: kind,
            container: 'mp4',
            headers: cdnHeaders(pageUrl: pageUrl, origin: origin),
          ),
        );
      }
    }
    return found.values.toList();
  }

  static String unescapeUrl(String raw) {
    return raw
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\u002F', '/')
        .replaceAll(r'\/', '/')
        .replaceAll(r'\\u0026', '&')
        .replaceAll('&amp;', '&');
  }

  static String decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  Future<int?> headSize(String url, Map<String, String> headers) async {
    try {
      final head = await dio.head(
        url,
        options: Options(
          headers: headers,
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      return int.tryParse(head.headers.value('content-length') ?? '');
    } catch (_) {
      return null;
    }
  }
}

String? extractUrlFromText(String text) {
  final regex = RegExp(r'https?://[^\s<>"{}|\\^`\[\]]+', caseSensitive: false);
  final match = regex.firstMatch(text.trim());
  if (match == null) return null;
  return match.group(0)!.replaceAll(RegExp(r'[)\]},.!?]+$'), '');
}
