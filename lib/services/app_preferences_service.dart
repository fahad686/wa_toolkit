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
}
