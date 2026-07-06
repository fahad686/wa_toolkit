import '../features/deleted_messages/data/services/message_store_service.dart';
import '../features/media_downloader/data/services/download_manager_service.dart';
import 'local_cache_service.dart';

class UsageStats {
  final int activeStatuses;
  final int savedStatuses;
  final int vaultedStatuses;
  final int favoriteStatuses;
  final int capturedMessages;
  final int deletedMessages;
  final int downloadCount;

  const UsageStats({
    required this.activeStatuses,
    required this.savedStatuses,
    required this.vaultedStatuses,
    required this.favoriteStatuses,
    required this.capturedMessages,
    required this.deletedMessages,
    required this.downloadCount,
  });
}

class UsageStatsService {
  final LocalCacheService cache;
  final MessageStoreService messages;
  final DownloadManagerService? downloads;

  UsageStatsService({
    required this.cache,
    required this.messages,
    this.downloads,
  });

  UsageStats compute() {
    final all = cache.getAllIncludingMissing();
    return UsageStats(
      activeStatuses: cache.getAllActive().length,
      savedStatuses: cache.getSaved().length,
      vaultedStatuses: cache.getVaulted().length,
      favoriteStatuses: all.where((i) => i.isFavorite).length,
      capturedMessages: messages.all().length,
      deletedMessages: messages.deletedOnly().length,
      downloadCount: downloads?.completedCount ?? 0,
    );
  }
}
