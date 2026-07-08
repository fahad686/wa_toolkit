import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app_preferences_service.dart';

/// Alerts user on repeated failed vault unlock attempts.
class VaultIntruderService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  AppPreferencesService? _prefs;

  Future<void> init(AppPreferencesService prefs) async {
    _prefs = prefs;
    if (!Platform.isAndroid || _initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    _initialized = true;
  }

  Future<void> recordFailedAttempt(int count) async {
    if (!_initialized || count < 3) return;
    if (_prefs?.vaultBreakInAlerts == false) return;
    await _plugin.show(
      9001,
      'Vault security alert',
      count >= 5
          ? 'Vault locked for 30 seconds after $count failed attempts.'
          : '$count failed unlock attempts detected.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'vault_security',
          'Vault security',
          channelDescription: 'Alerts for failed vault unlock attempts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
