import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/status_item.dart';
import 'whatsapp_paths.dart';

enum StatusFilter { all, images, videos, audio, saved, vaulted, missing }

class LocalCacheService {
  static const _boxName = 'status_items';
  static const _settingsBoxName = 'settings';

  late Box<StatusItem> _box;
  late Box _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(StatusItemAdapter());
    }
    _box = await Hive.openBox<StatusItem>(_boxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
  }

  Future<void> saveFolderUri(WhatsAppVariant variant, String uri) =>
      _settingsBox.put(WhatsAppPaths.settingsKeyFor(variant), uri);

  Future<String?> getFolderUri(WhatsAppVariant variant) async =>
      _settingsBox.get(WhatsAppPaths.settingsKeyFor(variant)) as String?;

  Future<void> clearFolderUri(WhatsAppVariant variant) async =>
      _settingsBox.delete(WhatsAppPaths.settingsKeyFor(variant));

  Future<bool> hasItem(String id) async => _box.containsKey(id);

  Future<void> putItem(StatusItem item) async => _box.put(item.id, item);

  StatusItem? getById(String id) => _box.get(id);

  List<StatusItem> _sorted(Iterable<StatusItem> items) =>
      items.toList()..sort((a, b) => b.discoveredAt.compareTo(a.discoveredAt));

  List<StatusItem> getAllIncludingMissing() => _sorted(_box.values);

  List<StatusItem> getAllActive({WhatsAppVariant? variant}) {
    final now = DateTime.now();
    var items = _box.values.where((i) => i.isProtected || i.expiresAt.isAfter(now));
    if (variant != null) {
      items = items.where((i) => i.sourceIndex == variant.sourceIndex);
    }
    return _sorted(items.where((i) => !i.isVaulted));
  }

  List<StatusItem> getSaved({WhatsAppVariant? variant}) {
    var items = _box.values.where((i) => i.isSaved && !i.isVaulted);
    if (variant != null) {
      items = items.where((i) => i.sourceIndex == variant.sourceIndex);
    }
    return _sorted(items);
  }

  List<StatusItem> getVaulted({WhatsAppVariant? variant}) {
    var items = _box.values.where((i) => i.isVaulted);
    if (variant != null) {
      items = items.where((i) => i.sourceIndex == variant.sourceIndex);
    }
    return _sorted(items);
  }

  List<StatusItem> getMissing({WhatsAppVariant? variant}) {
    var items = _box.values.where((i) => i.isMissing);
    if (variant != null) {
      items = items.where((i) => i.sourceIndex == variant.sourceIndex);
    }
    return _sorted(items);
  }

  List<StatusItem> filter(StatusFilter f, {WhatsAppVariant? variant}) {
    final base = switch (f) {
      StatusFilter.all => getAllActive(variant: variant),
      StatusFilter.images =>
        getAllActive(variant: variant).where((i) => i.mediaType == StatusMediaType.image),
      StatusFilter.videos =>
        getAllActive(variant: variant).where((i) => i.mediaType == StatusMediaType.video),
      StatusFilter.audio =>
        getAllActive(variant: variant).where((i) => i.mediaType == StatusMediaType.audio),
      StatusFilter.saved => getSaved(variant: variant),
      StatusFilter.vaulted => getVaulted(variant: variant),
      StatusFilter.missing => getMissing(variant: variant),
    };
    return _sorted(base);
  }

  Future<int> sweepExpired() async {
    final expiredKeys = <dynamic>[];
    for (final item in _box.values) {
      if (item.isExpired) {
        await _deleteFileIfExists(item.cachedFilePath);
        if (item.savedFilePath != null) await _deleteFileIfExists(item.savedFilePath!);
        expiredKeys.add(item.id);
      }
    }
    for (final key in expiredKeys) {
      await _box.delete(key);
    }
    return expiredKeys.length;
  }

  Future<StatusItem> saveItem(StatusItem item) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final savedDir = Directory(p.join(docsDir.path, 'saved_statuses'));
    if (!await savedDir.exists()) await savedDir.create(recursive: true);

    final source = File(item.displayPath);
    if (!await source.exists()) throw StateError('Cannot save — file is missing.');

    final destPath = p.join(savedDir.path, '${item.id}${p.extension(source.path)}');
    if (source.path != destPath) await source.copy(destPath);

    item.isSaved = true;
    item.savedFilePath = destPath;
    item.isMissing = false;
    await item.save();
    return item;
  }

  Future<StatusItem> moveToVault(StatusItem item) async {
    final vaultDir = await _vaultDirectory();
    final source = File(item.displayPath);
    if (!await source.exists()) throw StateError('Cannot vault — file is missing.');

    final destPath = p.join(vaultDir.path, '${item.id}${p.extension(source.path)}');
    if (source.path != destPath) {
      await source.copy(destPath);
      if (!item.isSaved && source.path == item.cachedFilePath) {
        await _deleteFileIfExists(item.cachedFilePath);
      }
    }

    item.isVaulted = true;
    item.vaultedFilePath = destPath;
    item.isSaved = false;
    item.savedFilePath = null;
    item.isMissing = false;
    await item.save();
    return item;
  }

  Future<void> deleteItem(StatusItem item) async {
    await _deleteFileIfExists(item.cachedFilePath);
    if (item.savedFilePath != null) await _deleteFileIfExists(item.savedFilePath!);
    if (item.vaultedFilePath != null) await _deleteFileIfExists(item.vaultedFilePath!);
    await _box.delete(item.id);
  }

  Future<void> updateCachedPath(StatusItem item, String newPath) async {
    item.cachedFilePath = newPath;
    item.isMissing = false;
    await item.save();
  }

  Future<void> markDeletedFromWhatsApp(StatusItem item) async {
    item.deletedFromWhatsApp = true;
    await item.save();
  }

  Future<Directory> _vaultDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final vaultDir = Directory(p.join(supportDir.path, 'secure_vault'));
    if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
    return vaultDir;
  }

  Future<void> _deleteFileIfExists(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
