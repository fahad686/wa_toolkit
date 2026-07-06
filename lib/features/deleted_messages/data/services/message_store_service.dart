import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../services/whatsapp_paths.dart';
import '../models/captured_message.dart';

class MessageStoreService {
  static const _boxName = 'captured_messages';

  late Box<CapturedMessage> _box;

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(CapturedMessageAdapter());
    }
    _box = await Hive.openBox<CapturedMessage>(_boxName);
  }

  Future<bool> has(String id) async => _box.containsKey(id);

  Future<void> put(CapturedMessage message) => _box.put(message.id, message);

  CapturedMessage? getById(String id) => _box.get(id);

  List<CapturedMessage> all({WhatsAppVariant? variant, bool? savedOnly}) {
    var items = _box.values.toList();
    if (variant != null) {
      items = items.where((m) => m.sourceIndex == variant.sourceIndex).toList();
    }
    if (savedOnly == true) {
      items = items.where((m) => m.isSaved).toList();
    }
    items.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return items;
  }

  List<CapturedMessage> deletedOnly({WhatsAppVariant? variant}) {
    return all(variant: variant).where((m) => m.isLikelyDeleted).toList();
  }

  Future<void> saveMessage(CapturedMessage message) async {
    message.isSaved = true;
    await message.save();
  }

  Future<void> deleteMessage(CapturedMessage message) async {
    await _box.delete(message.id);
  }

  String idFor(String package, String title, String content, int timestamp) =>
      sha1.convert(utf8.encode('$package|$title|$content|$timestamp')).toString();
}
