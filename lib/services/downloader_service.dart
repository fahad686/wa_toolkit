import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum MediaKind { video, audio, file }

/// One downloadable option for a given piece of media, e.g.
/// "720p MP4", "1080p MP4", "MP3 192kbps", "Original file".
///
/// IMPORTANT: `variants` must come from a source you control or that
/// explicitly provides direct, licensed download links (your own API/CDN,
/// a user-provided direct URL, etc). This service intentionally does NOT
/// scrape or extract media from third-party platforms (YouTube, Instagram,
/// TikTok, etc) — doing so violates those platforms' Terms of Service and
/// can infringe copyright. Point it at direct URLs you have the right to use.
class MediaVariant {
  final String label; // "1080p", "192kbps MP3", "Original"
  final String url;
  final MediaKind kind;
  final int? approxSizeBytes;

  const MediaVariant({
    required this.label,
    required this.url,
    required this.kind,
    this.approxSizeBytes,
  });
}

class DownloadProgress {
  final String variantLabel;
  final int received;
  final int total;
  double get fraction => total <= 0 ? 0 : received / total;
  DownloadProgress(this.variantLabel, this.received, this.total);
}

class DownloaderService {
  final Dio _dio = Dio();

  /// Fetches variant metadata from your own backend, given a link the
  /// user pasted in. Replace this with a call to your actual API —
  /// this stub just shows the expected shape.
  Future<List<MediaVariant>> resolveVariants(String sourceUrl) async {
    // Example: your backend inspects `sourceUrl` (something you have
    // rights/license to serve) and returns available renditions.
    final response = await _dio.get(
      'https://your-backend.example.com/resolve',
      queryParameters: {'url': sourceUrl},
    );
    final data = response.data as Map<String, dynamic>;
    final list = (data['variants'] as List).cast<Map<String, dynamic>>();
    return list
        .map((v) => MediaVariant(
              label: v['label'] as String,
              url: v['url'] as String,
              kind: MediaKind.values.byName(v['kind'] as String),
              approxSizeBytes: v['size'] as int?,
            ))
        .toList();
  }

  Future<String> download(
    MediaVariant variant, {
    void Function(DownloadProgress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final subfolder = switch (variant.kind) {
      MediaKind.video => 'videos',
      MediaKind.audio => 'audio',
      MediaKind.file => 'files',
    };
    final destDir = p.join(dir.path, 'downloads', subfolder);
    await Directory(destDir).create(recursive: true);
    final fileName = p.basename(Uri.parse(variant.url).path);
    final destPath = p.join(destDir, fileName.isEmpty ? '${variant.label}.dat' : fileName);

    await _dio.download(
      variant.url,
      destPath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        onProgress?.call(DownloadProgress(variant.label, received, total));
      },
    );

    return destPath;
  }
}
