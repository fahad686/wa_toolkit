import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart';

class ThumbnailService {
  Future<String?> generateForVideo(String videoPath, String outputDir) async {
    try {
      final dir = Directory(outputDir);
      if (!await dir.exists()) await dir.create(recursive: true);

      final thumb = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: outputDir,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 320,
        quality: 80,
      );
      return thumb;
    } catch (_) {
      return null;
    }
  }

  String thumbnailPathFor(String videoPath, String outputDir) =>
      p.join(outputDir, '${p.basenameWithoutExtension(videoPath)}.jpg');
}
