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

  List<CapturedMessage> search(String query, {WhatsAppVariant? variant}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all(variant: variant);
    return all(variant: variant)
        .where((m) =>
            m.senderName.toLowerCase().contains(q) || m.content.toLowerCase().contains(q))
        .toList();
  }

  List<CapturedMessage> filtered({
    WhatsAppVariant? variant,
    bool? savedOnly,
    bool? deletedOnly,
    bool? groupsOnly,
    String? query,
  }) {
    var items = all(variant: variant, savedOnly: savedOnly);
    if (deletedOnly == true) {
      items = items.where((m) => m.isLikelyDeleted).toList();
    }
    if (groupsOnly == true) {
      items = items.where((m) => m.isGroupChat).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      items = items
          .where((m) =>
              m.senderName.toLowerCase().contains(q) || m.content.toLowerCase().contains(q))
          .toList();
    }
    return items;
  }

  Map<String, List<CapturedMessage>> groupBySender({WhatsAppVariant? variant}) {
    final map = <String, List<CapturedMessage>>{};
    for (final msg in all(variant: variant)) {
      map.putIfAbsent(msg.senderName, () => []).add(msg);
    }
    for (final list in map.values) {
      list.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) {
        final aTime = a.value.first.capturedAt;
        final bTime = b.value.first.capturedAt;
        return bTime.compareTo(aTime);
      }),
    );
  }

  List<CapturedMessage> deletedOnly({WhatsAppVariant? variant}) {
    return filtered(variant: variant, deletedOnly: true);
  }

  String exportText(Iterable<CapturedMessage> messages) {
    final buffer = StringBuffer();
    for (final m in messages) {
      buffer.writeln('From: ${m.senderName}');
      buffer.writeln('At: ${m.capturedAt.toIso8601String()}');
      buffer.writeln(m.content);
      buffer.writeln('---');
    }
    return buffer.toString();
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
