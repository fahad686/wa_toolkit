import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app_preferences_service.dart';

/// Shows local notifications when deleted messages are captured.
class DeletedMessageAlertService {
  final AppPreferencesService prefs;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  DeletedMessageAlertService(this.prefs);

  Future<void> init() async {
    if (!Platform.isAndroid || _initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    _initialized = true;

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }
  }

  Future<void> notifyDeleted({required String sender, required String preview}) async {
    if (!prefs.deletedAlertsEnabled || !_initialized) return;

    await _plugin.show(
      sender.hashCode,
      'Message deleted in $sender',
      preview.length > 120 ? '${preview.substring(0, 120)}…' : preview,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'deleted_messages',
          'Deleted message alerts',
          channelDescription: 'Alerts when a WhatsApp message is deleted',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }
}
