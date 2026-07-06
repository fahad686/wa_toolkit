import 'package:hive/hive.dart';
import '../../../../services/whatsapp_paths.dart';

part 'captured_message.g.dart';

@HiveType(typeId: 1)
class CapturedMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String senderName;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime capturedAt;

  @HiveField(4, defaultValue: 0)
  final int sourceIndex;

  @HiveField(5, defaultValue: false)
  bool isSaved;

  @HiveField(6, defaultValue: false)
  bool wasRemoved;

  @HiveField(7, defaultValue: false)
  bool isDeletedNotice;

  CapturedMessage({
    required this.id,
    required this.senderName,
    required this.content,
    required this.capturedAt,
    this.sourceIndex = 0,
    this.isSaved = false,
    this.wasRemoved = false,
    this.isDeletedNotice = false,
  });

  WhatsAppVariant get variant =>
      sourceIndex == WhatsAppVariant.business.sourceIndex
          ? WhatsAppVariant.business
          : WhatsAppVariant.regular;

  bool get isLikelyDeleted =>
      isDeletedNotice || wasRemoved || looksDeleted(content);

  static bool looksDeleted(String text) {
    final lower = text.toLowerCase();
    return lower.contains('message was deleted') ||
        lower.contains('this message was deleted') ||
        lower.contains('deleted this message');
  }
}
