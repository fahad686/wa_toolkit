import 'package:hive/hive.dart';

part 'status_item.g.dart';

enum StatusMediaType { image, video, audio }

enum WhatsAppSource { regular, business }

/// Represents one WhatsApp status cached locally by the app.
@HiveType(typeId: 0)
class StatusItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String cachedFilePath;

  @HiveField(2)
  final int mediaTypeIndex;

  @HiveField(3)
  final DateTime discoveredAt;

  @HiveField(4)
  final DateTime expiresAt;

  @HiveField(5)
  bool isSaved;

  @HiveField(6)
  String? savedFilePath;

  @HiveField(7)
  final String? sourceHint;

  @HiveField(8, defaultValue: false)
  bool isVaulted;

  @HiveField(9)
  String? vaultedFilePath;

  @HiveField(10)
  final String? originalFileName;

  @HiveField(11)
  final int? originalSizeBytes;

  @HiveField(12, defaultValue: false)
  bool isMissing;

  @HiveField(13, defaultValue: 0)
  final int sourceIndex;

  @HiveField(14)
  final DateTime? sourceModifiedAt;

  @HiveField(15, defaultValue: false)
  bool deletedFromWhatsApp;

  @HiveField(16)
  String? thumbnailPath;

  StatusItem({
    required this.id,
    required this.cachedFilePath,
    required this.mediaTypeIndex,
    required this.discoveredAt,
    required this.expiresAt,
    this.isSaved = false,
    this.savedFilePath,
    this.sourceHint,
    this.isVaulted = false,
    this.vaultedFilePath,
    this.originalFileName,
    this.originalSizeBytes,
    this.isMissing = false,
    this.sourceIndex = 0,
    this.sourceModifiedAt,
    this.deletedFromWhatsApp = false,
    this.thumbnailPath,
  });

  StatusMediaType get mediaType => StatusMediaType.values[mediaTypeIndex];

  WhatsAppSource get source => WhatsAppSource.values[sourceIndex.clamp(0, WhatsAppSource.values.length - 1)];

  bool get isExpired => !isSaved && !isVaulted && DateTime.now().isAfter(expiresAt);

  Duration get timeRemaining =>
      expiresAt.isAfter(DateTime.now()) ? expiresAt.difference(DateTime.now()) : Duration.zero;

  String get displayPath => vaultedFilePath ?? savedFilePath ?? cachedFilePath;

  bool get isProtected => isSaved || isVaulted;

  String get contactLabel => sourceHint ?? 'Unknown contact';
}
