import 'dart:async';
import 'package:flutter/services.dart';

/// Receives links shared from other apps (YouTube, browser, etc.).
class ShareLinkService {
  static const _channel = MethodChannel('com.meftech.watoolkit/share');

  final _linkController = StreamController<String>.broadcast();
  Stream<String> get links => _linkController.stream;

  String? _pendingLink;

  String? get pendingLink => _pendingLink;

  String? consumePendingLink() {
    final link = _pendingLink;
    _pendingLink = null;
    return link;
  }

  Future<void> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedLink') {
        final link = call.arguments as String?;
        if (link != null && link.isNotEmpty) {
          _pendingLink = link;
          _linkController.add(link);
        }
      }
    });

    try {
      final initial = await _channel.invokeMethod<String>('getInitialLink');
      if (initial != null && initial.isNotEmpty) {
        _pendingLink = initial;
      }
    } catch (_) {}
  }

  void dispose() => _linkController.close();
}
