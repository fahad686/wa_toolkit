import '../models/status_item.dart';
import '../services/local_cache_service.dart';
import '../services/vault_service.dart';
import '../features/deleted_messages/data/models/captured_message.dart';
import '../features/deleted_messages/data/services/message_store_service.dart';

class SearchResult {
  final List<StatusItem> statuses;
  final List<CapturedMessage> messages;

  const SearchResult({required this.statuses, required this.messages});

  bool get isEmpty => statuses.isEmpty && messages.isEmpty;
  int get total => statuses.length + messages.length;
}

class GlobalSearchService {
  final LocalCacheService cache;
  final MessageStoreService messages;
  final VaultService vault;

  GlobalSearchService({
    required this.cache,
    required this.messages,
    required this.vault,
  });

  SearchResult search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return const SearchResult(statuses: [], messages: []);
    }

    final statuses = cache.getAllIncludingMissing().where((item) {
      if (item.isVaulted && !vault.isUnlocked) return false;
      return item.contactLabel.toLowerCase().contains(q) ||
          (item.originalFileName?.toLowerCase().contains(q) ?? false) ||
          item.collectionTags.any((t) => t.toLowerCase().contains(q)) ||
          (item.vaultFolder?.toLowerCase().contains(q) ?? false);
    }).toList();

    final msgs = messages.all().where((m) {
      return m.senderName.toLowerCase().contains(q) || m.content.toLowerCase().contains(q);
    }).toList();

    return SearchResult(statuses: statuses, messages: msgs);
  }
}
