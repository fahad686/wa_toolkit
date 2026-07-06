import 'package:hive/hive.dart';
import 'media_variant.dart';

part 'download_task.g.dart';

enum DownloadStatus { queued, downloading, completed, failed, cancelled }

@HiveType(typeId: 2)
class DownloadTask extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String sourceUrl;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final String variantLabel;

  @HiveField(4)
  final int kindIndex;

  @HiveField(5)
  int statusIndex;

  @HiveField(6)
  double progress;

  @HiveField(7)
  String? localPath;

  @HiveField(8)
  String? error;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  int? fileSizeBytes;

  @HiveField(11)
  final String downloadUrl;

  @HiveField(12)
  String? refererUrl;

  @HiveField(13)
  final String? platform;

  DownloadTask({
    required this.id,
    required this.sourceUrl,
    required this.title,
    required this.variantLabel,
    required this.kindIndex,
    this.statusIndex = 0,
    this.progress = 0,
    this.localPath,
    this.error,
    required this.createdAt,
    this.fileSizeBytes,
    required this.downloadUrl,
    this.refererUrl,
    this.platform,
  });

  MediaKind get kind => MediaKind.values[kindIndex.clamp(0, MediaKind.values.length - 1)];
  DownloadStatus get status =>
      DownloadStatus.values[statusIndex.clamp(0, DownloadStatus.values.length - 1)];

  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;

  factory DownloadTask.fromVariant({
    required String id,
    required String sourceUrl,
    required String title,
    required String platform,
    required MediaVariant variant,
  }) {
    return DownloadTask(
      id: id,
      sourceUrl: sourceUrl,
      title: title,
      variantLabel: variant.label,
      kindIndex: variant.kind.index,
      downloadUrl: variant.url,
      createdAt: DateTime.now(),
      fileSizeBytes: variant.approxSizeBytes,
      refererUrl: variant.headers?['Referer'] ?? sourceUrl,
      platform: platform,
    );
  }
}
