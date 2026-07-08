import 'package:hive_flutter/hive_flutter.dart';

class VaultNote {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  VaultNote({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory VaultNote.fromMap(Map map) => VaultNote(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        createdAt: DateTime.parse(map['createdAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
      );
}

class VaultNoteService {
  static const _boxName = 'vault_notes';
  Box? _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  List<VaultNote> all() {
    final box = _box;
    if (box == null) return [];
    return box.values
        .map((v) => VaultNote.fromMap(Map<String, dynamic>.from(v as Map)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<VaultNote> save({String? id, required String title, required String body}) async {
    final box = _box!;
    final now = DateTime.now();
    final noteId = id ?? 'note_${now.millisecondsSinceEpoch}';
    final existing = id != null ? get(id) : null;
    final note = VaultNote(
      id: noteId,
      title: title.trim(),
      body: body,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await box.put(noteId, note.toMap());
    return note;
  }

  VaultNote? get(String id) {
    final raw = _box?.get(id);
    if (raw == null) return null;
    return VaultNote.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> delete(String id) => _box!.delete(id);
}
