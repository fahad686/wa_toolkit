import 'dart:io';
import '../models/media_variant.dart';

/// Validates that a downloaded file is real media, not an HTML error page.
class MediaFileValidator {
  static Future<bool> isValid(String path, MediaKind kind) async {
    final file = File(path);
    if (!await file.exists()) return false;

    final length = await file.length();
    if (length < 512) return false;

    final raf = await file.open();
    try {
      final header = await raf.read(16);
      if (_looksLikeHtml(header)) return false;

      return switch (kind) {
        MediaKind.video => _isVideo(header),
        MediaKind.audio => _isAudio(header),
        MediaKind.file => _isImage(header) || (!_looksLikeHtml(header) && header.length >= 4),
      };
    } finally {
      await raf.close();
    }
  }

  static bool _looksLikeHtml(List<int> bytes) {
    if (bytes.isEmpty) return true;
    final start = String.fromCharCodes(bytes.take(12)).toLowerCase().trim();
    return start.startsWith('<!doctype') ||
        start.startsWith('<html') ||
        start.startsWith('<head') ||
        start.startsWith('<?xml');
  }

  static bool _isVideo(List<int> bytes) {
    if (bytes.length >= 8) {
      final ftyp = String.fromCharCodes(bytes.sublist(4, 8));
      if (ftyp == 'ftyp') return true;
    }
    if (bytes.length >= 4 && bytes[0] == 0x1A && bytes[1] == 0x45 && bytes[2] == 0xDF) {
      return true;
    }
    return false;
  }

  static bool _isAudio(List<int> bytes) {
    if (_isVideo(bytes)) return true;
    if (bytes.length >= 3 && bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
      return true; // ID3
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) {
      return true; // MP3 frame sync
    }
    return false;
  }

  static bool _isImage(List<int> bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true; // JPEG
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true; // PNG
    }
    if (bytes.length >= 4 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return true; // GIF
    }
    return false;
  }
}
