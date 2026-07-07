import 'package:path/path.dart' as p;
import '../../../../models/status_item.dart';
import '../models/media_variant.dart';
import '../models/download_task.dart';

const _imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic'};

bool isImagePath(String? path) {
  if (path == null) return false;
  return _imageExtensions.contains(p.extension(path).toLowerCase());
}

bool isDownloadImage(DownloadTask task) {
  if (task.kind == MediaKind.file) return isImagePath(task.localPath);
  return isImagePath(task.localPath) || task.variantLabel.toLowerCase().contains('image');
}

bool isDownloadFile(DownloadTask task) {
  return task.kind == MediaKind.file && !isDownloadImage(task);
}

StatusMediaType statusTypeForDownload(DownloadTask task) {
  if (task.kind == MediaKind.video) return StatusMediaType.video;
  if (task.kind == MediaKind.audio) return StatusMediaType.audio;
  if (isDownloadImage(task)) return StatusMediaType.image;
  return StatusMediaType.video;
}
