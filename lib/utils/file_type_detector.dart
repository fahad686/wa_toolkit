import 'dart:typed_data';
import '../models/status_item.dart';

class DetectedMedia {
  final StatusMediaType type;
  final String extension;

  const DetectedMedia(this.type, this.extension);
}

/// WhatsApp stores statuses with random names and often no extension.
/// Detect type from the first bytes of the file.
DetectedMedia? detectMediaFromHeader(Uint8List header) {
  if (header.length < 4) return null;

  if (header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) {
    return const DetectedMedia(StatusMediaType.image, '.jpg');
  }

  if (header.length >= 8 &&
      header[0] == 0x89 &&
      header[1] == 0x50 &&
      header[2] == 0x4E &&
      header[3] == 0x47) {
    return const DetectedMedia(StatusMediaType.image, '.png');
  }

  if (header.length >= 12 &&
      header[0] == 0x52 &&
      header[1] == 0x49 &&
      header[2] == 0x46 &&
      header[3] == 0x46 &&
      header[8] == 0x57 &&
      header[9] == 0x45 &&
      header[10] == 0x42 &&
      header[11] == 0x50) {
    return const DetectedMedia(StatusMediaType.image, '.webp');
  }

  if (header.length >= 8 && String.fromCharCodes(header.sublist(4, 8)) == 'ftyp') {
    if (header.length >= 12) {
      final brand = String.fromCharCodes(header.sublist(8, 12));
      if (brand.contains('3gp')) {
        return const DetectedMedia(StatusMediaType.video, '.3gp');
      }
    }
    return const DetectedMedia(StatusMediaType.video, '.mp4');
  }

  if (header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46) {
    return const DetectedMedia(StatusMediaType.image, '.gif');
  }

  return null;
}
