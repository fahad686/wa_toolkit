import 'package:intl/intl.dart';

String formatDurationRemaining(Duration d) {
  if (d.inHours >= 1) return '${d.inHours}h left';
  if (d.inMinutes >= 1) return '${d.inMinutes}m left';
  return 'Expiring soon';
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatDateTime(DateTime dt) => DateFormat.yMMMd().add_jm().format(dt);
