import '../models/status_item.dart';

const imageExtensions = {'.jpg', '.jpeg', '.png', '.webp'};
const videoExtensions = {'.mp4', '.3gp', '.mkv', '.webm'};
const audioExtensions = {'.mp3', '.m4a', '.aac', '.ogg', '.opus'};

StatusMediaType mediaTypeForExtension(String ext) {
  final lower = ext.toLowerCase();
  if (imageExtensions.contains(lower)) return StatusMediaType.image;
  if (videoExtensions.contains(lower)) return StatusMediaType.video;
  if (audioExtensions.contains(lower)) return StatusMediaType.audio;
  return StatusMediaType.image;
}

bool isSupportedMediaExtension(String ext) {
  final lower = ext.toLowerCase();
  return imageExtensions.contains(lower) ||
      videoExtensions.contains(lower) ||
      audioExtensions.contains(lower);
}
