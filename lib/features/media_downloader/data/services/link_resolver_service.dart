import '../models/media_variant.dart';
import 'dailymotion_resolver.dart';
import 'direct_url_resolver.dart';
import 'facebook_resolver.dart';
import 'hls_resolver.dart';
import 'instagram_resolver.dart';
import 'page_resolver_utils.dart';
import 'pinterest_resolver.dart';
import 'snapchat_resolver.dart';
import 'tiktok_resolver.dart';
import 'twitter_resolver.dart';
import 'vimeo_resolver.dart';
import 'youtube_resolver.dart';

export 'page_resolver_utils.dart' show extractUrlFromText;

class LinkResolverService {
  final YoutubeResolver _youtube = YoutubeResolver();
  final InstagramResolver _instagram = InstagramResolver();
  final TiktokResolver _tiktok = TiktokResolver();
  final FacebookResolver _facebook = FacebookResolver();
  final TwitterResolver _twitter = TwitterResolver();
  final SnapchatResolver _snapchat = SnapchatResolver();
  final PinterestResolver _pinterest = PinterestResolver();
  final VimeoResolver _vimeo = VimeoResolver();
  final DailymotionResolver _dailymotion = DailymotionResolver();
  final DirectUrlResolver _direct = DirectUrlResolver();
  final HlsResolver _hls = HlsResolver();

  Future<ResolvedMedia> resolve(String input) async {
    final url = extractUrlFromText(input) ?? input.trim();
    if (!url.startsWith('http')) {
      throw ArgumentError('Paste a valid http(s) link.');
    }

    if (_youtube.canHandle(url)) return _youtube.resolve(url);
    if (_instagram.canHandle(url)) return _instagram.resolve(url);
    if (_tiktok.canHandle(url)) return _tiktok.resolve(url);
    if (_facebook.canHandle(url)) return _facebook.resolve(url);
    if (_twitter.canHandle(url)) return _twitter.resolve(url);
    if (_snapchat.canHandle(url)) return _snapchat.resolve(url);
    if (_pinterest.canHandle(url)) return _pinterest.resolve(url);
    if (_vimeo.canHandle(url)) return _vimeo.resolve(url);
    if (_dailymotion.canHandle(url)) return _dailymotion.resolve(url);

    if (_hls.canHandle(url)) {
      final result = await _hls.resolve(url);
      if (result != null) return result;
    }

    final direct = await _direct.resolve(url);
    if (direct != null) return direct;

    throw StateError(
      'Could not resolve this link. Supported: YouTube, Instagram, TikTok, Facebook, '
      'X/Twitter, Snapchat, Pinterest, Vimeo, Dailymotion, direct media URLs, and HLS.',
    );
  }

  String platformHint(String input) {
    final url = extractUrlFromText(input) ?? input;
    if (_youtube.canHandle(url)) return 'YouTube';
    if (_instagram.canHandle(url)) return 'Instagram';
    if (_tiktok.canHandle(url)) return 'TikTok';
    if (_facebook.canHandle(url)) return 'Facebook';
    if (_twitter.canHandle(url)) return 'X (Twitter)';
    if (_snapchat.canHandle(url)) return 'Snapchat';
    if (_pinterest.canHandle(url)) return 'Pinterest';
    if (_vimeo.canHandle(url)) return 'Vimeo';
    if (_dailymotion.canHandle(url)) return 'Dailymotion';
    if (_hls.canHandle(url)) return 'HLS stream';
    return 'Direct link';
  }

  void dispose() => _youtube.dispose();
}
