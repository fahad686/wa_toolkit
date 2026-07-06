import 'package:dio/dio.dart';
import '../models/media_variant.dart';

/// Only handles URLs that point directly to media files (not social page links).
class DirectUrlResolver {
  final Dio _dio = Dio();

  static const _blockedHosts = [
    'instagram.com',
    'facebook.com',
    'fb.watch',
    'fb.com',
    'tiktok.com',
    'twitter.com',
    'x.com',
    'snapchat.com',
    'pinterest.com',
    'pin.it',
    'vimeo.com',
    'dailymotion.com',
    'dai.ly',
    'youtube.com',
    'youtu.be',
  ];

  bool canHandle(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return false;
    if (!_isDirectMediaUrl(lower) && _isBlockedHost(url)) return false;
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  Future<ResolvedMedia?> resolve(String url) async {
    if (_isBlockedHost(url) && !_isDirectMediaUrl(url.toLowerCase())) {
      return null;
    }

    try {
      final head = await _dio.head(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final type = head.headers.value('content-type')?.toLowerCase() ?? '';

      if (type.contains('text/html') || type.contains('application/json')) {
        return null;
      }

      final length = int.tryParse(head.headers.value('content-length') ?? '');
      final fileName = Uri.parse(url).pathSegments.isNotEmpty
          ? Uri.parse(url).pathSegments.last
          : 'download';

      MediaKind kind;
      String label;
      if (type.contains('video') || _isVideoExt(url)) {
        kind = MediaKind.video;
        label = 'Video — $fileName';
      } else if (type.contains('audio') || _isAudioExt(url)) {
        kind = MediaKind.audio;
        label = 'Audio — $fileName';
      } else if (type.contains('image')) {
        kind = MediaKind.file;
        label = 'Image — $fileName';
      } else {
        kind = MediaKind.file;
        label = 'File — $fileName';
      }

      return ResolvedMedia(
        sourceUrl: url,
        title: fileName,
        platform: 'Direct link',
        variants: [
          MediaVariant(
            id: 'direct_0',
            label: label,
            url: url,
            kind: kind,
            approxSizeBytes: length,
            container: fileName.split('.').lastOrNull,
          ),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  bool _isBlockedHost(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return _blockedHosts.any((h) => host.contains(h));
  }

  bool _isDirectMediaUrl(String url) {
    const exts = [
      '.mp4', '.webm', '.mkv', '.mov', '.mp3', '.m4a', '.aac', '.wav', '.opus',
      '.jpg', '.jpeg', '.png', '.gif', '.webp',
    ];
    return exts.any((e) => url.contains(e));
  }

  bool _isVideoExt(String url) {
    const exts = ['.mp4', '.webm', '.mkv', '.mov', '.avi', '.3gp'];
    return exts.any((e) => url.toLowerCase().contains(e));
  }

  bool _isAudioExt(String url) {
    const exts = ['.mp3', '.m4a', '.aac', '.ogg', '.wav', '.opus'];
    return exts.any((e) => url.toLowerCase().contains(e));
  }
}
