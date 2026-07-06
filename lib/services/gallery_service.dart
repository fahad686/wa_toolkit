import 'dart:io';
import 'package:gal/gal.dart';
import '../models/status_item.dart';

/// Saves status media into the device gallery (Pictures / Movies).
class GalleryService {
  Future<void> saveToGallery(StatusItem item) async {
    final file = File(item.displayPath);
    if (!await file.exists()) {
      throw StateError('File is missing — try "Repair missing files" first.');
    }

    switch (item.mediaType) {
      case StatusMediaType.image:
        await Gal.putImage(file.path);
      case StatusMediaType.video:
        await Gal.putVideo(file.path);
      case StatusMediaType.audio:
        // Gal has no audio API — copy to Music folder via putImage fallback won't work.
        // Use putVideo as last resort or just throw with helpful message.
        throw UnsupportedError('Audio statuses cannot be saved to gallery on this device.');
    }
  }

  String galleryLabelFor(StatusItem item) => switch (item.mediaType) {
        StatusMediaType.image => 'Pictures',
        StatusMediaType.video => 'Movies',
        StatusMediaType.audio => 'Music',
      };
}
