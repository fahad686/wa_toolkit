import '../models/status_item.dart';
import 'app_preferences_service.dart';
import 'local_cache_service.dart';

/// Auto-move saved statuses into vault based on user rules.
class AutoVaultService {
  final AppPreferencesService prefs;
  final LocalCacheService cache;

  AutoVaultService({required this.prefs, required this.cache});

  Future<int> applyAfterSave(StatusItem item) async {
    if (!prefs.autoVaultEnabled || item.isVaulted) return 0;
    if (!_matches(item)) return 0;
    try {
      await cache.moveToVault(item, folder: prefs.autoVaultFolder);
      return 1;
    } catch (_) {
      return 0;
    }
  }

  bool _matches(StatusItem item) {
    if (prefs.autoVaultVideosOnly && item.mediaType != StatusMediaType.video) {
      return false;
    }
    final contacts = prefs.autoVaultContacts.map((c) => c.toLowerCase()).toSet();
    if (contacts.isNotEmpty && !contacts.contains(item.contactLabel.toLowerCase())) {
      return false;
    }
    return true;
  }
}
