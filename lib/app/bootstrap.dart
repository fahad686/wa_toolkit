import 'package:hive/hive.dart';
import '../features/deleted_messages/data/services/message_store_service.dart';
import '../features/deleted_messages/data/services/notification_capture_service.dart';
import '../features/media_downloader/data/services/download_manager_service.dart';
import '../features/media_downloader/data/services/link_resolver_service.dart';
import '../features/media_downloader/data/services/share_link_service.dart';
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
import '../services/app_preferences_service.dart';
import '../services/auto_save_service.dart';
import '../services/deleted_message_alert_service.dart';
import '../services/download_notification_service.dart';
import '../services/global_search_service.dart';
import '../services/usage_stats_service.dart';

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
  final AppPreferencesService prefs;
  final UsageStatsService stats;
  final GlobalSearchService search;
  final AutoSaveService autoSave;
  final DeletedMessageAlertService deletedAlerts;
  final LinkResolverService linkResolver;
  final DownloadManagerService downloadManager;
  final ShareLinkService shareLinks;

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
    required this.prefs,
    required this.stats,
    required this.search,
    required this.autoSave,
    required this.deletedAlerts,
    required this.linkResolver,
    required this.downloadManager,
    required this.shareLinks,
  });

  static late final AppServices I;

  static Future<AppServices> init() async {
    final cache = LocalCacheService();
    await cache.init();

    final settingsBox = await Hive.openBox('settings');
    final theme = ThemeNotifier(settingsBox);
    final prefs = AppPreferencesService(settingsBox);

    final thumbnails = ThumbnailService();
    final autoSave = AutoSaveService(prefs: prefs, cache: cache);
    final scanner = StatusScannerService(cache, thumbnails, autoSave);
    await scanner.restoreAllAccess();

    final messages = MessageStoreService();
    await messages.init();

    final deletedAlerts = DeletedMessageAlertService(prefs);
    await deletedAlerts.init();

    final downloadNotifications = DownloadNotificationService(prefs);
    await downloadNotifications.init();

    final notificationCapture = NotificationCaptureService(messages, deletedAlerts, prefs);
    await notificationCapture.start();

    final linkResolver = LinkResolverService();
    final downloadManager = DownloadManagerService(downloadNotifications);
    await downloadManager.init();

    final shareLinks = ShareLinkService();
    await shareLinks.init();

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
      prefs: prefs,
      stats: UsageStatsService(cache: cache, messages: messages, downloads: downloadManager),
      search: GlobalSearchService(cache: cache, messages: messages),
      autoSave: autoSave,
      deletedAlerts: deletedAlerts,
      linkResolver: linkResolver,
      downloadManager: downloadManager,
      shareLinks: shareLinks,
    );

    services.watch.start();
    I = services;
    return services;
  }
}
