import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app_preferences_service.dart';

class DownloadNotificationService {
  final AppPreferencesService prefs;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  DownloadNotificationService(this.prefs);

  Future<void> init() async {
    if (!Platform.isAndroid || _initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    _initialized = true;
  }

  Future<void> notifyComplete({required String title, required String label}) async {
    if (!prefs.downloadAlertsEnabled || !_initialized) return;
    await _plugin.show(
      title.hashCode,
      'Download complete',
      '$title — $label',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'downloads',
          'Download alerts',
          channelDescription: 'Notifies when a media download finishes',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }
}
