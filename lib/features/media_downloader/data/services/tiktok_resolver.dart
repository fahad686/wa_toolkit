import 'dart:convert';

import 'package:dio/dio.dart';
import '../models/media_variant.dart';
import 'page_resolver_utils.dart';

class TiktokResolver {
  static const _hosts = ['tiktok.com', 'tiktokv.com'];
  static const _origin = 'https://www.tiktok.com';
  static const _tikwmApi = 'https://www.tikwm.com/api/';

  final PageResolverUtils _utils = PageResolverUtils();
  final Dio _dio = Dio(BaseOptions(
    headers: {
      'User-Agent': PageResolverUtils.mobileUserAgent,
      'Accept': 'text/html,application/xhtml+xml,application/json',
      'Accept-Language': 'en-US,en;q=0.9',
    },
    followRedirects: true,
    validateStatus: (s) => s != null && s < 500,
  ));

  bool canHandle(String url) => _utils.hostMatches(url, _hosts);

  Future<ResolvedMedia> resolve(String url) async {
    final inputUrl = extractUrlFromText(url) ?? url.trim();
    final pageUrl = await _followRedirects(inputUrl);

    final html = await _utils.fetchHtml(pageUrl);
    final headers = _utils.cdnHeaders(pageUrl: pageUrl, origin: _origin);

    var variants = _extractFromHtml(html, headers: headers);
    String? thumbnail = _utils.ogImage(html);
    String? title = _utils.ogTitle(html) ?? _utils.pageTitle(html);

    if (variants.isEmpty) {
      final fallback = await _fetchViaTikwm(inputUrl, headers);
      variants = fallback.variants;
      title ??= fallback.title;
      thumbnail ??= fallback.thumbnailUrl;
    }

    if (variants.isEmpty) {
      throw StateError(
        'Could not extract TikTok video. The post may be private, removed, or region-locked.',
      );
    }

    return _utils.buildResult(
      sourceUrl: pageUrl,
      platform: 'TikTok',
      title: title ?? 'TikTok video',
      thumbnailUrl: thumbnail,
      variants: variants,
    );
  }

  Future<String> _followRedirects(String url) async {
    try {
      final response = await _dio.head(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      return response.realUri.toString();
    } catch (_) {
      try {
        final response = await _dio.get<String>(
          url,
          options: Options(
            followRedirects: true,
            validateStatus: (s) => s != null && s < 500,
          ),
        );
        return response.realUri.toString();
      } catch (_) {
        return _utils.normalizeUrl(url);
      }
    }
  }

  List<MediaVariant> _extractFromHtml(
    String html, {
    required Map<String, String> headers,
  }) {
    final patterns = [
      RegExp(r'"downloadAddr":"([^"]+)"'),
      RegExp(r'"playAddr":"([^"]+)"'),
      RegExp(r'"playApi":"([^"]+)"'),
      RegExp(r'"PlayAddr":\s*\{\s*"Uri":"([^"]+)"'),
      RegExp(r'"DownloadAddr":\s*\{\s*"Uri":"([^"]+)"'),
      RegExp(r'"src":"(https://[^"]+\.mp4[^"]*)"'),
      RegExp(r'"url":"(https://[^"]*tiktokcdn[^"]+)"'),
    ];

    final videoUrl = _utils.firstMatch(html, patterns) ?? _utils.ogVideo(html);
    if (videoUrl == null) {
      final fromState = _extractFromUniversalData(html, headers);
      if (fromState.isNotEmpty) return fromState;
      return [];
    }

    return [
      MediaVariant(
        id: 'tiktok_video',
        label: 'Video MP4',
        url: videoUrl,
        kind: MediaKind.video,
        resolution: 'Original',
        container: 'mp4',
        headers: headers,
      ),
    ];
  }

  List<MediaVariant> _extractFromUniversalData(
    String html,
    Map<String, String> headers,
  ) {
    final match = RegExp(
      r'<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>(.*?)</script>',
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return [];

    try {
      final data = jsonDecode(match.group(1)!);
      final urls = <String>[];
      _walkForVideoUrls(data, urls);
      return urls.asMap().entries
          .map(
            (e) => MediaVariant(
              id: 'tiktok_video_${e.key}',
              label: 'Video MP4',
              url: e.value,
              kind: MediaKind.video,
              resolution: 'Original',
              container: 'mp4',
              headers: headers,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _walkForVideoUrls(dynamic node, List<String> urls) {
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key.toString().toLowerCase();
        final value = entry.value;
        if ((key == 'playaddr' ||
                key == 'downloadaddr' ||
                key == 'playapi' ||
                key == 'uri') &&
            value is String &&
            value.startsWith('http') &&
            (value.contains('tiktok') || value.contains('.mp4'))) {
          final url = PageResolverUtils.unescapeUrl(value);
          if (!urls.contains(url)) urls.add(url);
        } else {
          _walkForVideoUrls(value, urls);
        }
      }
    } else if (node is List) {
      for (final item in node) {
        _walkForVideoUrls(item, urls);
      }
    }
  }

  Future<({List<MediaVariant> variants, String? title, String? thumbnailUrl})> _fetchViaTikwm(
    String url,
    Map<String, String> headers,
  ) async {
    final response = await _dio.get<String>(
      _tikwmApi,
      queryParameters: {'url': url, 'hd': '1'},
      options: Options(
        headers: {'Accept': 'application/json'},
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    final body = response.data;
    if (body == null || body.isEmpty) return (variants: <MediaVariant>[], title: null, thumbnailUrl: null);

    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['code'] != 0) {
      final msg = json['msg']?.toString() ?? 'TikTok extraction failed';
      throw StateError(msg);
    }

    final data = json['data'] as Map<String, dynamic>? ?? {};
    final variants = <MediaVariant>[];

    final hdPlay = data['hdplay'] as String?;
    final play = data['play'] as String?;
    final music = data['music'] as String?;
    final videoSize = data['size'] as int?;
    final duration = data['duration'] as int?;

    final author = data['author'] as Map<String, dynamic>?;
    final nickname = author?['nickname'] as String?;
    final uniqueId = author?['unique_id'] as String?;
    final desc = (data['title'] as String?)?.trim();
    final title = (desc != null && desc.isNotEmpty)
        ? desc
        : (nickname ?? uniqueId ?? 'TikTok video');

    if (hdPlay != null && hdPlay.startsWith('http')) {
      variants.add(
        MediaVariant(
          id: 'tiktok_video_hd',
          label: _formatLabel('Video MP4 (HD)', videoSize, duration),
          url: hdPlay,
          kind: MediaKind.video,
          approxSizeBytes: videoSize,
          resolution: 'HD',
          container: 'mp4',
          headers: headers,
        ),
      );
    }

    if (play != null && play.startsWith('http') && play != hdPlay) {
      variants.add(
        MediaVariant(
          id: 'tiktok_video',
          label: _formatLabel('Video MP4', videoSize, duration),
          url: play,
          kind: MediaKind.video,
          approxSizeBytes: videoSize,
          resolution: 'Original',
          container: 'mp4',
          headers: headers,
        ),
      );
    } else if (play != null && play.startsWith('http') && hdPlay == null) {
      variants.add(
        MediaVariant(
          id: 'tiktok_video',
          label: _formatLabel('Video MP4', videoSize, duration),
          url: play,
          kind: MediaKind.video,
          approxSizeBytes: videoSize,
          resolution: 'Original',
          container: 'mp4',
          headers: headers,
        ),
      );
    }

    if (music != null && music.startsWith('http')) {
      final musicInfo = data['music_info'] as Map<String, dynamic>?;
      final musicDuration = musicInfo?['duration'] as int? ?? duration;
      variants.add(
        MediaVariant(
          id: 'tiktok_audio',
          label: _formatLabel('Music MP3', null, musicDuration),
          url: music,
          kind: MediaKind.audio,
          container: 'mp3',
          headers: headers,
        ),
      );
    }

    return (
      variants: variants,
      title: title,
      thumbnailUrl: data['cover'] as String? ?? data['origin_cover'] as String?,
    );
  }

  String _formatLabel(String base, int? sizeBytes, int? durationSeconds) {
    final parts = <String>[base];
    if (sizeBytes != null && sizeBytes > 0) {
      parts.add(_formatBytes(sizeBytes));
    }
    if (durationSeconds != null && durationSeconds > 0) {
      parts.add('${durationSeconds}s');
    }
    return parts.join(' · ');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}kB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
