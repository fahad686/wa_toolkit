import 'package:hive/hive.dart';
import '../features/deleted_messages/data/services/message_store_service.dart';
import '../features/deleted_messages/data/services/notification_capture_service.dart';
import '../services/downloader_service.dart';
import '../services/file_repair_service.dart';
import '../services/gallery_service.dart';
import '../services/local_cache_service.dart';
import '../services/share_service.dart';
import '../services/status_scanner_service.dart';
import '../services/status_watch_service.dart';
import '../services/thumbnail_service.dart';
import '../services/vault_service.dart';
import 'theme/theme_notifier.dart';

/// Global service container — initialized once at app start.
class AppServices {
  final LocalCacheService cache;
  final StatusScannerService scanner;
  final DownloaderService downloader;
  final GalleryService gallery;
  final ShareService share;
  final VaultService vault;
  final FileRepairService repair;
  final StatusWatchService watch;
  final ThumbnailService thumbnails;
  final MessageStoreService messages;
  final NotificationCaptureService notificationCapture;
  final ThemeNotifier theme;

  AppServices._({
    required this.cache,
    required this.scanner,
    required this.downloader,
    required this.gallery,
    required this.share,
    required this.vault,
    required this.repair,
    required this.watch,
    required this.thumbnails,
    required this.messages,
    required this.notificationCapture,
    required this.theme,
  });

  static late final AppServices I;

  static Future<AppServices> init() async {
    final cache = LocalCacheService();
    await cache.init();

    final settingsBox = await Hive.openBox('settings');
    final theme = ThemeNotifier(settingsBox);

    final thumbnails = ThumbnailService();
    final scanner = StatusScannerService(cache, thumbnails);
    await scanner.restoreAllAccess();

    final messages = MessageStoreService();
    await messages.init();

    final notificationCapture = NotificationCaptureService(messages);
    await notificationCapture.start();

    final services = AppServices._(
      cache: cache,
      scanner: scanner,
      downloader: DownloaderService(),
      gallery: GalleryService(),
      share: ShareService(),
      vault: VaultService(),
      repair: FileRepairService(cache, scanner),
      watch: StatusWatchService(scanner),
      thumbnails: thumbnails,
      messages: messages,
      notificationCapture: notificationCapture,
      theme: theme,
    );

    services.watch.start();
    I = services;
    return services;
  }
}
