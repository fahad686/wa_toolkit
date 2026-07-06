import 'package:hive/hive.dart';

/// App-wide preferences stored in the settings Hive box.
class AppPreferencesService {
  static const _autoSaveEnabled = 'auto_save_enabled';
  static const _autoSaveVideosOnly = 'auto_save_videos_only';
  static const _autoSaveContacts = 'auto_save_contacts';
  static const _promptVaultAfterSave = 'prompt_vault_after_save';
  static const _deletedAlertsEnabled = 'deleted_alerts_enabled';
  static const _onboardingDone = 'onboarding_done';
  static const _onboardingStatus = 'onboarding_status';
  static const _onboardingMessages = 'onboarding_messages';
  static const _onboardingVault = 'onboarding_vault';
  static const _recentDownloadUrls = 'recent_download_urls';
  static const _downloadAlertsEnabled = 'download_alerts_enabled';
  static const _favoriteDownloadIds = 'favorite_download_ids';
  static const _downloadPlaylists = 'download_playlists';

  final Box _box;

  AppPreferencesService(this._box);

  bool get autoSaveEnabled => _box.get(_autoSaveEnabled, defaultValue: false) as bool;
  Future<void> setAutoSaveEnabled(bool v) => _box.put(_autoSaveEnabled, v);

  bool get autoSaveVideosOnly => _box.get(_autoSaveVideosOnly, defaultValue: false) as bool;
  Future<void> setAutoSaveVideosOnly(bool v) => _box.put(_autoSaveVideosOnly, v);

  List<String> get autoSaveContacts {
    final raw = _box.get(_autoSaveContacts);
    if (raw is List) return raw.cast<String>();
    return [];
  }

  Future<void> setAutoSaveContacts(List<String> contacts) =>
      _box.put(_autoSaveContacts, contacts);

  bool get promptVaultAfterSave => _box.get(_promptVaultAfterSave, defaultValue: false) as bool;
  Future<void> setPromptVaultAfterSave(bool v) => _box.put(_promptVaultAfterSave, v);

  bool get deletedAlertsEnabled => _box.get(_deletedAlertsEnabled, defaultValue: true) as bool;
  Future<void> setDeletedAlertsEnabled(bool v) => _box.put(_deletedAlertsEnabled, v);

  bool get onboardingDone => _box.get(_onboardingDone, defaultValue: false) as bool;
  Future<void> setOnboardingDone(bool v) => _box.put(_onboardingDone, v);

  bool get onboardingStatus => _box.get(_onboardingStatus, defaultValue: false) as bool;
  Future<void> setOnboardingStatus(bool v) => _box.put(_onboardingStatus, v);

  bool get onboardingMessages => _box.get(_onboardingMessages, defaultValue: false) as bool;
  Future<void> setOnboardingMessages(bool v) => _box.put(_onboardingMessages, v);

  bool get onboardingVault => _box.get(_onboardingVault, defaultValue: false) as bool;
  Future<void> setOnboardingVault(bool v) => _box.put(_onboardingVault, v);

  bool get downloadAlertsEnabled => _box.get(_downloadAlertsEnabled, defaultValue: true) as bool;
  Future<void> setDownloadAlertsEnabled(bool v) => _box.put(_downloadAlertsEnabled, v);

  List<String> get recentDownloadUrls {
    final raw = _box.get(_recentDownloadUrls);
    if (raw is List) return raw.cast<String>();
    return [];
  }

  Future<void> addRecentDownloadUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final list = recentDownloadUrls.where((u) => u != trimmed).toList();
    list.insert(0, trimmed);
    if (list.length > 8) list.removeRange(8, list.length);
    await _box.put(_recentDownloadUrls, list);
  }

  List<String> get favoriteDownloadIds {
    final raw = _box.get(_favoriteDownloadIds);
    if (raw is List) return raw.cast<String>();
    return [];
  }

  bool isFavoriteDownload(String taskId) => favoriteDownloadIds.contains(taskId);

  Future<void> toggleFavoriteDownload(String taskId) async {
    final list = favoriteDownloadIds.toList();
    if (list.contains(taskId)) {
      list.remove(taskId);
    } else {
      list.insert(0, taskId);
    }
    await _box.put(_favoriteDownloadIds, list);
  }

  Map<String, List<String>> get downloadPlaylists {
    final raw = _box.get(_downloadPlaylists);
    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(
          key.toString(),
          value is List ? value.cast<String>() : <String>[],
        ),
      );
    }
    return {};
  }

  List<String> get downloadPlaylistNames =>
      downloadPlaylists.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  List<String> playlistsForDownload(String taskId) {
    final names = <String>[];
    for (final entry in downloadPlaylists.entries) {
      if (entry.value.contains(taskId)) names.add(entry.key);
    }
    return names;
  }

  Future<void> addDownloadToPlaylist(String taskId, String playlistName) async {
    final name = playlistName.trim();
    if (name.isEmpty) return;
    final map = downloadPlaylists.map((k, v) => MapEntry(k, List<String>.from(v)));
    final list = map.putIfAbsent(name, () => []);
    if (!list.contains(taskId)) list.add(taskId);
    await _box.put(_downloadPlaylists, map);
  }

  Future<void> removeDownloadFromPlaylist(String taskId, String playlistName) async {
    final map = downloadPlaylists.map((k, v) => MapEntry(k, List<String>.from(v)));
    map[playlistName]?.remove(taskId);
    if (map[playlistName]?.isEmpty ?? false) map.remove(playlistName);
    await _box.put(_downloadPlaylists, map);
  }

  Future<void> deleteDownloadPlaylist(String playlistName) async {
    final map = downloadPlaylists.map((k, v) => MapEntry(k, List<String>.from(v)));
    map.remove(playlistName);
    await _box.put(_downloadPlaylists, map);
  }

  Future<void> createDownloadPlaylist(String playlistName) async {
    final name = playlistName.trim();
    if (name.isEmpty) return;
    final map = downloadPlaylists.map((k, v) => MapEntry(k, List<String>.from(v)));
    map.putIfAbsent(name, () => []);
    await _box.put(_downloadPlaylists, map);
  }
}
