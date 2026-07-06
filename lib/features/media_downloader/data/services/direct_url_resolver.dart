import 'package:dio/dio.dart';
import '../models/media_variant.dart';

class DirectUrlResolver {
  final Dio _dio = Dio();

  bool canHandle(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return false;
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  Future<ResolvedMedia?> resolve(String url) async {
    try {
      final head = await _dio.head(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final type = head.headers.value('content-type')?.toLowerCase() ?? '';
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

  bool _isVideoExt(String url) {
    const exts = ['.mp4', '.webm', '.mkv', '.mov', '.avi', '.3gp'];
    return exts.any((e) => url.toLowerCase().contains(e));
  }

  bool _isAudioExt(String url) {
    const exts = ['.mp3', '.m4a', '.aac', '.ogg', '.wav', '.opus'];
    return exts.any((e) => url.toLowerCase().contains(e));
  }
}
