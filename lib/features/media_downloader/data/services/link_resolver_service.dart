import '../models/media_variant.dart';
import 'direct_url_resolver.dart';
import 'hls_resolver.dart';
import 'youtube_resolver.dart';

/// Extracts a URL from shared/pasted text.
String? extractUrlFromText(String text) {
  final regex = RegExp(r'https?://[^\s<>"{}|\\^`\[\]]+', caseSensitive: false);
  final match = regex.firstMatch(text.trim());
  if (match == null) return null;
  return match.group(0)!.replaceAll(RegExp(r'[)\]},.!?]+$'), '');
}

class LinkResolverService {
  final YoutubeResolver _youtube = YoutubeResolver();
  final DirectUrlResolver _direct = DirectUrlResolver();
  final HlsResolver _hls = HlsResolver();

  Future<ResolvedMedia> resolve(String input) async {
    final url = extractUrlFromText(input) ?? input.trim();
    if (!url.startsWith('http')) {
      throw ArgumentError('Paste a valid http(s) link.');
    }

    if (_youtube.canHandle(url)) {
      return _youtube.resolve(url);
    }

    if (_hls.canHandle(url)) {
      final result = await _hls.resolve(url);
      if (result != null) return result;
    }

    final direct = await _direct.resolve(url);
    if (direct != null) return direct;

    throw StateError(
      'Could not resolve this link. Supported: YouTube, direct media URLs, and HLS (.m3u8).',
    );
  }

  String platformHint(String input) {
    final url = extractUrlFromText(input) ?? input;
    if (_youtube.canHandle(url)) return 'YouTube';
    if (_hls.canHandle(url)) return 'HLS stream';
    return 'Direct link';
  }

  void dispose() => _youtube.dispose();
}
