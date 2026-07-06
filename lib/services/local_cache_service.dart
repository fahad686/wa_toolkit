import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/status_item.dart';
import 'whatsapp_paths.dart';

enum StatusFilter { all, images, videos, audio, saved, vaulted, missing, favorites }

enum StatusDateFilter { all, today, last7Days }

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

  List<StatusItem> filter(
    StatusFilter f, {
    WhatsAppVariant? variant,
    StatusDateFilter dateFilter = StatusDateFilter.all,
    String? contactQuery,
    String? collectionTag,
  }) {
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
      StatusFilter.favorites =>
        getAllActive(variant: variant).where((i) => i.isFavorite),
    };
    return _sorted(_applyDateAndContact(base, dateFilter, contactQuery, collectionTag));
  }

  List<StatusItem> getVaultedInFolder(String? folder, {WhatsAppVariant? variant}) {
    var items = getVaulted(variant: variant);
    if (folder == null || folder.isEmpty) {
      return items.where((i) => i.vaultFolder == null || i.vaultFolder!.isEmpty).toList();
    }
    return items.where((i) => i.vaultFolder == folder).toList();
  }

  List<String> vaultFolders() {
    final folders = <String>{};
    for (final item in _box.values) {
      if (item.isVaulted && item.vaultFolder != null && item.vaultFolder!.isNotEmpty) {
        folders.add(item.vaultFolder!);
      }
    }
    return folders.toList()..sort();
  }

  List<String> contactLabels({WhatsAppVariant? variant}) {
    final labels = <String>{};
    for (final item in getAllActive(variant: variant)) {
      labels.add(item.contactLabel);
    }
    return labels.toList()..sort();
  }

  List<String> collectionTags({WhatsAppVariant? variant}) {
    final tags = <String>{};
    for (final item in getAllActive(variant: variant)) {
      tags.addAll(item.collectionTags);
    }
    return tags.toList()..sort();
  }

  Future<void> toggleFavorite(StatusItem item) async {
    item.isFavorite = !item.isFavorite;
    await item.save();
  }

  Future<void> setVaultFolder(StatusItem item, String? folder) async {
    item.vaultFolder = folder?.trim().isEmpty == true ? null : folder?.trim();
    await item.save();
  }

  Future<void> addCollectionTag(StatusItem item, String tag) async {
    final t = tag.trim();
    if (t.isEmpty || item.collectionTags.contains(t)) return;
    item.collectionTags = [...item.collectionTags, t];
    await item.save();
  }

  Future<void> removeCollectionTag(StatusItem item, String tag) async {
    item.collectionTags = item.collectionTags.where((t) => t != tag).toList();
    await item.save();
  }

  List<StatusItem> _applyDateAndContact(
    Iterable<StatusItem> items,
    StatusDateFilter dateFilter,
    String? contactQuery,
    String? collectionTag,
  ) {
    var result = items;
    final now = DateTime.now();
    result = switch (dateFilter) {
      StatusDateFilter.all => result,
      StatusDateFilter.today => result.where((i) {
          final d = i.sourceModifiedAt ?? i.discoveredAt;
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }),
      StatusDateFilter.last7Days => result.where((i) {
          final d = i.sourceModifiedAt ?? i.discoveredAt;
          return now.difference(d).inDays <= 7;
        }),
    };
    if (contactQuery != null && contactQuery.isNotEmpty) {
      final q = contactQuery.toLowerCase();
      result = result.where((i) => i.contactLabel.toLowerCase().contains(q));
    }
    if (collectionTag != null && collectionTag.isNotEmpty) {
      result = result.where((i) => i.collectionTags.contains(collectionTag));
    }
    return result.toList();
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

  Future<StatusItem> importFileToVault({
    required String sourcePath,
    required String title,
    required StatusMediaType mediaType,
    String? folder,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw StateError('File not found on device.');

    final vaultDir = await _vaultDirectory();
    final id = 'dl_${DateTime.now().millisecondsSinceEpoch}_${sourcePath.hashCode.abs()}';
    final ext = p.extension(sourcePath);
    final destPath = p.join(vaultDir.path, '$id$ext');
    await source.copy(destPath);

    final now = DateTime.now();
    final item = StatusItem(
      id: id,
      cachedFilePath: destPath,
      mediaTypeIndex: mediaType.index,
      discoveredAt: now,
      expiresAt: now.add(const Duration(days: 36500)),
      isVaulted: true,
      vaultedFilePath: destPath,
      originalFileName: p.basename(sourcePath),
      originalSizeBytes: await source.length(),
      sourceHint: title,
      vaultFolder: folder?.trim().isEmpty == true ? null : folder?.trim(),
    );
    await putItem(item);
    return item;
  }

  Future<StatusItem> moveToVault(StatusItem item, {String? folder}) async {
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
    if (folder != null && folder.trim().isNotEmpty) {
      item.vaultFolder = folder.trim();
    }
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
