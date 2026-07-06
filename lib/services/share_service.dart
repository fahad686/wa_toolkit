import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../models/status_item.dart';

/// Shares status media via the system share sheet.
class ShareService {
  Future<void> shareStatus(StatusItem item) async {
    final file = File(item.displayPath);
    if (!await file.exists()) {
      throw StateError('File is missing — try "Repair missing files" first.');
    }

    final ext = item.originalFileName != null
        ? p.extension(item.originalFileName!).toLowerCase()
        : p.extension(file.path).toLowerCase();

    await Share.shareXFiles(
      [XFile(file.path, mimeType: _mimeFor(item.mediaType, ext))],
      text: 'Shared from WA Toolkit',
    );
  }
}

String? _mimeFor(StatusMediaType type, String ext) => switch (type) {
      StatusMediaType.image => switch (ext) {
          '.png' => 'image/png',
          '.webp' => 'image/webp',
          _ => 'image/jpeg',
        },
      StatusMediaType.video => 'video/mp4',
      StatusMediaType.audio => switch (ext) {
          '.m4a' => 'audio/mp4',
          '.ogg' => 'audio/ogg',
          '.opus' => 'audio/opus',
          _ => 'audio/mpeg',
        },
    };
