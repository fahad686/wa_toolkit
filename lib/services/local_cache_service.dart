import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/status_item.dart';
import 'thumbnail_service.dart';
import 'vault_crypto_service.dart';
import 'whatsapp_paths.dart';

enum StatusFilter { all, images, videos, audio, saved, vaulted, missing, favorites }

enum StatusDateFilter { all, today, last7Days }

enum VaultMediaFilter { all, images, videos, audio, favorites, downloads, local, files }

class VaultStats {
  final int itemCount;
  final int bytes;
  final int folderCount;

  const VaultStats({required this.itemCount, required this.bytes, required this.folderCount});
}

class LocalCacheService {
  static const _boxName = 'status_items';
  static const _settingsBoxName = 'settings';

  late Box<StatusItem> _box;
  late Box _settingsBox;
  VaultCryptoService? vaultCrypto;

  Future<void> init() async {
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

  List<StatusItem> filterVault(
    List<StatusItem> items, {
    VaultMediaFilter filter = VaultMediaFilter.all,
    String query = '',
  }) {
    var result = items;
    result = switch (filter) {
      VaultMediaFilter.all => result,
      VaultMediaFilter.images =>
        result.where((i) => i.mediaType == StatusMediaType.image).toList(),
      VaultMediaFilter.videos =>
        result.where((i) => i.mediaType == StatusMediaType.video).toList(),
      VaultMediaFilter.audio =>
        result.where((i) => i.mediaType == StatusMediaType.audio).toList(),
      VaultMediaFilter.favorites => result.where((i) => i.isFavorite).toList(),
      VaultMediaFilter.downloads => result.where((i) => i.id.startsWith('dl_')).toList(),
      VaultMediaFilter.local => result.where((i) => i.isLocalImport).toList(),
      VaultMediaFilter.files => result
          .where((i) =>
              i.id.startsWith('dl_') &&
              i.mediaType != StatusMediaType.image &&
              i.mediaType != StatusMediaType.video &&
              i.mediaType != StatusMediaType.audio)
          .toList(),
    };
    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      result = result
          .where((i) =>
              i.contactLabel.toLowerCase().contains(q) ||
              (i.originalFileName?.toLowerCase().contains(q) ?? false) ||
              (i.vaultFolder?.toLowerCase().contains(q) ?? false) ||
              (i.sourceHint?.toLowerCase().contains(q) ?? false) ||
              (i.originalLocationPath?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return result;
  }

  Future<VaultStats> vaultStats() async {
    final items = getVaulted();
    var bytes = 0;
    for (final item in items) {
      final path = item.vaultedFilePath ?? item.displayPath;
      final f = File(path);
      if (await f.exists()) bytes += await f.length();
    }
    return VaultStats(
      itemCount: items.length,
      bytes: bytes,
      folderCount: vaultFolders().length,
    );
  }

  Future<void> renameVaultFolder(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw ArgumentError('Folder name required');
    for (final item in getVaulted()) {
      if (item.vaultFolder == oldName) {
        item.vaultFolder = trimmed;
        await item.save();
      }
    }
  }

  Future<void> moveVaultItemToFolder(StatusItem item, String? folder) async {
    item.vaultFolder = folder?.trim().isEmpty == true ? null : folder?.trim();
    await item.save();
  }

  Future<String> readableMediaPath(StatusItem item) async {
    final path = item.displayPath;
    if (VaultCryptoService.isEncryptedPath(path) && vaultCrypto?.isUnlocked == true) {
      return vaultCrypto!.readablePath(path, cacheId: item.id);
    }
    return path;
  }

  Future<StatusItem> restoreFromVault(StatusItem item) async {
    if (!item.isVaulted) return item;
    final vaultPath = item.vaultedFilePath ?? item.displayPath;
    final source = File(vaultPath);
    if (!await source.exists()) throw StateError('Vault file is missing.');

    var workingPath = vaultPath;
    final usedTempDecrypt = VaultCryptoService.isEncryptedPath(vaultPath) && vaultCrypto?.isUnlocked == true;
    if (usedTempDecrypt) {
      workingPath = await vaultCrypto!.readablePath(vaultPath, cacheId: '${item.id}_restore');
    }

    final originalPath = item.originalLocationPath;
    if (originalPath != null && originalPath.isNotEmpty) {
      final destFile = File(originalPath);
      final parent = destFile.parent;
      if (!await parent.exists()) await parent.create(recursive: true);
      if (await destFile.exists()) await destFile.delete();
      await File(workingPath).copy(originalPath);

      await _deleteFileIfExists(vaultPath);
      if (usedTempDecrypt && workingPath != vaultPath) {
        await _deleteFileIfExists(workingPath);
      }
      if (item.thumbnailPath != null) await _deleteFileIfExists(item.thumbnailPath!);
      await _box.delete(item.id);
      return item;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final savedDir = Directory(p.join(docsDir.path, 'saved_statuses'));
    if (!await savedDir.exists()) await savedDir.create(recursive: true);

    final ext = p.extension(workingPath.replaceAll('.enc', ''));
    final destPath = p.join(savedDir.path, '${item.id}$ext');
    await File(workingPath).copy(destPath);

    item.isVaulted = false;
    item.vaultedFilePath = null;
    item.isSaved = true;
    item.savedFilePath = destPath;
    item.cachedFilePath = destPath;
    item.isMissing = false;
    await item.save();
    return item;
  }

  Future<int> encryptLegacyVaultFiles() async {
    if (vaultCrypto == null || !vaultCrypto!.isUnlocked) return 0;
    var count = 0;
    for (final item in getVaulted()) {
      final path = item.vaultedFilePath;
      if (path == null || VaultCryptoService.isEncryptedPath(path)) continue;

      final encPath = '$path${VaultCryptoService.encryptedExtension}';
      final encFile = File(encPath);
      if (await encFile.exists()) {
        item.vaultedFilePath = encPath;
        item.cachedFilePath = encPath;
        await item.save();
        continue;
      }

      final file = File(path);
      if (!await file.exists()) continue;

      if (item.thumbnailPath == null) {
        item.thumbnailPath = await _createThumbnailForVault(item.id, path, item.mediaType);
        await item.save();
      }

      final encrypted = await vaultCrypto!.encryptFile(path);
      item.vaultedFilePath = encrypted;
      item.cachedFilePath = encrypted;
      await item.save();
      count++;
    }
    return count;
  }

  /// Backfills thumbnails for encrypted vault items imported before thumbnail support.
  Future<void> ensureVaultThumbnails() async {
    if (vaultCrypto?.isUnlocked != true) return;
    for (final item in getVaulted()) {
      final thumb = item.thumbnailPath;
      if (thumb != null && File(thumb).existsSync()) continue;
      if (item.mediaType == StatusMediaType.audio) continue;
      try {
        final plain = await readableMediaPath(item);
        item.thumbnailPath = await _createThumbnailForVault(item.id, plain, item.mediaType);
        await item.save();
      } catch (_) {}
    }
  }

  Future<String> _finalizeVaultFile(String plainPath) async {
    if (vaultCrypto != null && vaultCrypto!.isUnlocked) {
      return vaultCrypto!.encryptFile(plainPath);
    }
    return plainPath;
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
    final finalPath = await _finalizeVaultFile(destPath);

    final now = DateTime.now();
    final item = StatusItem(
      id: id,
      cachedFilePath: finalPath,
      mediaTypeIndex: mediaType.index,
      discoveredAt: now,
      expiresAt: now.add(const Duration(days: 36500)),
      isVaulted: true,
      vaultedFilePath: finalPath,
      originalFileName: p.basename(sourcePath),
      originalSizeBytes: await source.length(),
      sourceHint: title,
      vaultFolder: folder?.trim().isEmpty == true ? null : folder?.trim(),
    );
    await putItem(item);
    return item;
  }

  /// Imports a file from device storage, moves it into the vault, and removes it from the original folder.
  Future<StatusItem> importLocalFileToVault({
    required String sourcePath,
    String? folder,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw StateError('File not found on device.');

    final originalLocation = source.absolute.path;
    final vaultDir = await _vaultDirectory();
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}_${originalLocation.hashCode.abs()}';
    final ext = p.extension(sourcePath);
    final destPath = p.join(vaultDir.path, '$id$ext');

    await _moveIntoVault(source, destPath);
    final mediaType = _mediaTypeForPath(sourcePath);
    final thumbPath = await _createThumbnailForVault(id, destPath, mediaType);
    final finalPath = await _finalizeVaultFile(destPath);

    final now = DateTime.now();
    final item = StatusItem(
      id: id,
      cachedFilePath: finalPath,
      mediaTypeIndex: mediaType.index,
      discoveredAt: now,
      expiresAt: now.add(const Duration(days: 36500)),
      isVaulted: true,
      vaultedFilePath: finalPath,
      originalFileName: p.basename(originalLocation),
      originalSizeBytes: await File(finalPath).exists() ? await File(finalPath).length() : 0,
      sourceHint: p.basename(originalLocation),
      vaultFolder: folder?.trim().isEmpty == true ? null : folder?.trim(),
      originalLocationPath: originalLocation,
      thumbnailPath: thumbPath,
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

    if (item.thumbnailPath == null) {
      item.thumbnailPath = await _createThumbnailForVault(item.id, destPath, item.mediaType);
    }
    final finalPath = await _finalizeVaultFile(destPath);

    item.isVaulted = true;
    item.vaultedFilePath = finalPath;
    item.cachedFilePath = finalPath;
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

  Future<Directory> _thumbnailDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(supportDir.path, 'vault_thumbs'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String?> _createThumbnailForVault(
    String itemId,
    String plainPath,
    StatusMediaType mediaType,
  ) async {
    final source = File(plainPath);
    if (!await source.exists()) return null;

    final thumbDir = await _thumbnailDirectory();
    switch (mediaType) {
      case StatusMediaType.image:
        final thumbPath = p.join(thumbDir.path, '$itemId.jpg');
        await source.copy(thumbPath);
        return thumbPath;
      case StatusMediaType.video:
        return ThumbnailService().generateForVideo(plainPath, thumbDir.path);
      case StatusMediaType.audio:
        return null;
    }
  }

  Future<Directory> _vaultDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final vaultDir = Directory(p.join(supportDir.path, 'secure_vault'));
    if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
    return vaultDir;
  }

  Future<void> _moveIntoVault(File source, String destPath) async {
    try {
      await source.rename(destPath);
    } catch (_) {
      await source.copy(destPath);
      try {
        await source.delete();
      } catch (_) {
        // Vault copy succeeded; original may remain if the OS blocks deletion.
      }
    }
  }

  StatusMediaType _mediaTypeForPath(String path) {
    final ext = p.extension(path).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic', '.heif'].contains(ext)) {
      return StatusMediaType.image;
    }
    if (['.mp4', '.mkv', '.mov', '.avi', '.webm', '.3gp', '.m4v'].contains(ext)) {
      return StatusMediaType.video;
    }
    if (['.mp3', '.m4a', '.wav', '.ogg', '.opus', '.aac', '.flac'].contains(ext)) {
      return StatusMediaType.audio;
    }
    return StatusMediaType.image;
  }

  Future<void> _deleteFileIfExists(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
