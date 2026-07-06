import '../models/status_item.dart';
import 'app_preferences_service.dart';
import 'local_cache_service.dart';

/// Applies auto-save rules after new statuses are cached.
class AutoSaveService {
  final AppPreferencesService prefs;
  final LocalCacheService cache;

  AutoSaveService({required this.prefs, required this.cache});

  Future<int> applyToNewItems(List<StatusItem> items) async {
    if (!prefs.autoSaveEnabled || items.isEmpty) return 0;

    final contacts = prefs.autoSaveContacts.map((c) => c.toLowerCase()).toSet();
    final videosOnly = prefs.autoSaveVideosOnly;
    var saved = 0;

    for (final item in items) {
      if (item.isSaved || item.isVaulted) continue;
      if (videosOnly && item.mediaType != StatusMediaType.video) continue;
      if (contacts.isNotEmpty && !contacts.contains(item.contactLabel.toLowerCase())) {
        continue;
      }
      try {
        await cache.saveItem(item);
        saved++;
      } catch (_) {}
    }
    return saved;
  }
}
