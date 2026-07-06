import 'dart:async';
import 'status_scanner_service.dart';
import 'whatsapp_paths.dart';

/// Polls WhatsApp folders every 20s to capture statuses before they are deleted.
class StatusWatchService {
  static const _interval = Duration(seconds: 20);

  final StatusScannerService _scanner;
  Timer? _timer;
  void Function(ScanResult result)? onScanComplete;

  StatusWatchService(this._scanner);

  void start() {
    _timer ??= Timer.periodic(_interval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> scanNow() => _tick();

  Future<void> _tick() async {
    for (final variant in WhatsAppVariant.values) {
      if (!await _scanner.hasAccess(variant)) continue;
      try {
        final result = await _scanner.scanAndCacheNewStatuses(variant);
        if (result.newlyCached > 0 || result.markedDeleted > 0) {
          onScanComplete?.call(result);
        }
      } catch (_) {}
    }
  }
}
