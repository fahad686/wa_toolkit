import 'dart:async';
import 'dart:io';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import '../../../../services/whatsapp_paths.dart';
import '../models/captured_message.dart';
import 'message_store_service.dart';

/// Captures WhatsApp notifications to preserve messages before/after deletion.
///
/// Requires notification listener permission (Android). WhatsApp does not expose
/// deleted chats via files — this listens to incoming notifications instead.
class NotificationCaptureService {
  static const _whatsappPackages = {'com.whatsapp', 'com.whatsapp.w4b'};

  final MessageStoreService _store;
  StreamSubscription<ServiceNotificationEvent>? _sub;

  NotificationCaptureService(this._store);

  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return false;
    return NotificationListenerService.isPermissionGranted();
  }

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    return NotificationListenerService.requestPermission();
  }

  Future<void> start() async {
    if (!Platform.isAndroid) return;
    if (!await hasPermission()) return;

    await _sub?.cancel();
    _sub = NotificationListenerService.notificationsStream.listen(_onEvent);
  }

  void stop() => _sub?.cancel();

  Future<void> _onEvent(ServiceNotificationEvent event) async {
    if (!_whatsappPackages.contains(event.packageName)) return;
    if (event.onGoing) return;

    final sender = event.title.trim().isEmpty ? 'Unknown' : event.title.trim();
    final content = event.content.trim();
    if (content.isEmpty && !event.hasRemoved) return;

    final variant = event.packageName == 'com.whatsapp.w4b'
        ? WhatsAppVariant.business
        : WhatsAppVariant.regular;

    final id = _store.idFor(event.packageName, sender, content, event.timestamp);
    if (await _store.has(id)) return;

    final message = CapturedMessage(
      id: id,
      senderName: sender,
      content: content.isEmpty ? '(notification removed)' : content,
      capturedAt: event.humanTime,
      sourceIndex: variant.sourceIndex,
      wasRemoved: event.hasRemoved,
      isDeletedNotice: CapturedMessage.looksDeleted(content),
    );

    await _store.put(message);
  }
}
