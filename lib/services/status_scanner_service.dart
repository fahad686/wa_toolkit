import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' show sha1;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart';
import 'package:saf_stream/saf_stream.dart';
import '../models/status_item.dart';
import '../utils/file_type_detector.dart';
import '../utils/media_utils.dart';
import 'auto_save_service.dart';
import 'local_cache_service.dart';
import 'thumbnail_service.dart';
import 'whatsapp_paths.dart';

class ScanResult {
  final int filesSeen;
  final int newlyCached;
  final int alreadyCached;
  final int skipped;
  final int foldersScanned;
  final int markedDeleted;

  const ScanResult({
    required this.filesSeen,
    required this.newlyCached,
    required this.alreadyCached,
    required this.skipped,
    required this.foldersScanned,
    this.markedDeleted = 0,
  });

  bool get foundStatusesFolder => foldersScanned > 0;
}

/// Reads WhatsApp `.Statuses` via SAF — separate access per variant.
class StatusScannerService {
  static const _minFileBytes = 256;
  static const _headerProbeBytes = 32;

  final SafUtil _safUtil = SafUtil();
  final SafStream _safStream = SafStream();
  final LocalCacheService _cache;
  final ThumbnailService? _thumbnails;
  final AutoSaveService? _autoSave;

  final Map<WhatsAppVariant, String> _folderUris = {};

  StatusScannerService(this._cache, [this._thumbnails, this._autoSave]);

  Future<bool> requestFolderAccess(WhatsAppVariant variant) async {
    final folder = await _safUtil.pickDirectory(
      initialUri: WhatsAppPaths.statusesUriFor(variant),
      writePermission: false,
      persistablePermission: true,
    );
    if (folder == null) return false;
    _folderUris[variant] = folder.uri;
    await _cache.saveFolderUri(variant, folder.uri);
    return true;
  }

  Future<bool> restoreAccess(WhatsAppVariant variant) async {
    if (_folderUris.containsKey(variant)) return true;

    final saved = await _cache.getFolderUri(variant);
    if (saved == null) return false;

    final stillValid =
        await _safUtil.hasPersistedPermission(saved) || await _safUtil.exists(saved, true);
    if (!stillValid) return false;

    _folderUris[variant] = saved;
    return true;
  }

  Future<bool> hasAccess(WhatsAppVariant variant) async {
    if (_folderUris.containsKey(variant)) return true;
    return restoreAccess(variant);
  }

  Future<void> clearFolderAccess(WhatsAppVariant variant) async {
    _folderUris.remove(variant);
    await _cache.clearFolderUri(variant);
  }

  Future<void> restoreAllAccess() async {
    for (final variant in WhatsAppVariant.values) {
      await restoreAccess(variant);
    }
  }

  Future<ScanResult> scanAndCacheNewStatuses(WhatsAppVariant variant) async {
    final folderUri = _folderUris[variant];
    if (folderUri == null) {
      throw StateError('Folder access not granted for ${variant.label}.');
    }

    final statusFolders = await _findStatusFolders(folderUri);
    if (statusFolders.isEmpty) {
      return const ScanResult(
        filesSeen: 0,
        newlyCached: 0,
        alreadyCached: 0,
        skipped: 0,
        foldersScanned: 0,
      );
    }

    final statusCacheDir = await _cacheDirectory(variant);
    int filesSeen = 0;
    int newlyCached = 0;
    int alreadyCached = 0;
    int skipped = 0;
    final newItems = <StatusItem>[];

    final liveFileNames = <String>{};

    for (final folderUri in statusFolders) {
      final entries = await _safUtil.list(folderUri);
      for (final entry in entries) {
        if (entry.isDir) continue;
        if (entry.length < _minFileBytes) {
          skipped++;
          continue;
        }

        liveFileNames.add(entry.name);
        filesSeen++;

        final resolved = await _resolveMedia(entry);
        if (resolved == null) {
          skipped++;
          continue;
        }

        final id = _idFor(variant, entry.name, entry.length);
        if (await _cache.hasItem(id)) {
          alreadyCached++;
          continue;
        }

        final destPath = p.join(statusCacheDir.path, '$id${resolved.extension}');
        await _safStream.copyToLocalFile(entry.uri, destPath);

        String? thumbPath;
        if (resolved.type == StatusMediaType.video && _thumbnails != null) {
          thumbPath = await _thumbnails!.generateForVideo(destPath, statusCacheDir.path);
        }

        final now = DateTime.now();
        final modifiedAt = entry.lastModified > 0
            ? DateTime.fromMillisecondsSinceEpoch(entry.lastModified)
            : now;

        final item = StatusItem(
          id: id,
          cachedFilePath: destPath,
          mediaTypeIndex: resolved.type.index,
          discoveredAt: now,
          expiresAt: now.add(const Duration(hours: 24)),
          originalFileName: entry.name,
          originalSizeBytes: entry.length,
          sourceIndex: variant.sourceIndex,
          sourceModifiedAt: modifiedAt,
          thumbnailPath: thumbPath,
        );

        await _cache.putItem(item);
        newItems.add(item);
        newlyCached++;
      }
    }

    if (_autoSave != null && newItems.isNotEmpty) {
      await _autoSave.applyToNewItems(newItems);
    }

    int markedDeleted = 0;
    for (final item in _cache.getAllActive(variant: variant)) {
      if (item.originalFileName == null || item.deletedFromWhatsApp) continue;
      if (!liveFileNames.contains(item.originalFileName)) {
        await _cache.markDeletedFromWhatsApp(item);
        markedDeleted++;
      }
    }

    return ScanResult(
      filesSeen: filesSeen,
      newlyCached: newlyCached,
      alreadyCached: alreadyCached,
      skipped: skipped,
      foldersScanned: statusFolders.length,
      markedDeleted: markedDeleted,
    );
  }

  Future<ScanResult> scanAllGranted() async {
    var total = const ScanResult(
      filesSeen: 0,
      newlyCached: 0,
      alreadyCached: 0,
      skipped: 0,
      foldersScanned: 0,
      markedDeleted: 0,
    );
    for (final variant in WhatsAppVariant.values) {
      if (!await hasAccess(variant)) continue;
      final r = await scanAndCacheNewStatuses(variant);
      total = ScanResult(
        filesSeen: total.filesSeen + r.filesSeen,
        newlyCached: total.newlyCached + r.newlyCached,
        alreadyCached: total.alreadyCached + r.alreadyCached,
        skipped: total.skipped + r.skipped,
        foldersScanned: total.foldersScanned + r.foldersScanned,
        markedDeleted: total.markedDeleted + r.markedDeleted,
      );
    }
    return total;
  }

  Future<bool> tryRepairItem(StatusItem item) async {
    final variant = WhatsAppSource.values[item.sourceIndex.clamp(0, 1)] == WhatsAppSource.business
        ? WhatsAppVariant.business
        : WhatsAppVariant.regular;

    final folderUri = _folderUris[variant];
    if (folderUri == null) return false;

    final statusFolders = await _findStatusFolders(folderUri);
    for (final folder in statusFolders) {
      final entries = await _safUtil.list(folder);
      for (final entry in entries) {
        if (entry.isDir) continue;
        final matchesName = item.originalFileName != null && entry.name == item.originalFileName;
        final matchesId = _idFor(variant, entry.name, entry.length) == item.id;
        if (!matchesName && !matchesId) continue;

        final resolved = await _resolveMedia(entry);
        if (resolved == null) continue;

        final statusCacheDir = await _cacheDirectory(variant);
        final destPath = p.join(statusCacheDir.path, '${item.id}${resolved.extension}');
        await _safStream.copyToLocalFile(entry.uri, destPath);
        await _cache.updateCachedPath(item, destPath);
        return true;
      }
    }
    return false;
  }

  Future<_ResolvedMedia?> _resolveMedia(SafDocumentFile entry) async {
    final ext = p.extension(entry.name).toLowerCase();
    if (isSupportedMediaExtension(ext)) {
      return _ResolvedMedia(mediaTypeForExtension(ext), ext);
    }

    final header = await _safStream.readFileBytes(entry.uri, count: _headerProbeBytes);
    final detected = detectMediaFromHeader(header);
    if (detected == null) return null;
    return _ResolvedMedia(detected.type, detected.extension);
  }

  Future<List<String>> _findStatusFolders(String rootUri) async {
    final directEntries = await _safUtil.list(rootUri);
    if (_looksLikeStatusFolder(directEntries)) return [rootUri];

    final found = <String>[];
    await _searchForStatuses(rootUri, found, depth: 0);
    return found;
  }

  bool _looksLikeStatusFolder(List<SafDocumentFile> entries) {
    int mediaLike = 0;
    for (final entry in entries) {
      if (entry.isDir) continue;
      if (entry.length < _minFileBytes) continue;
      final ext = p.extension(entry.name).toLowerCase();
      if (isSupportedMediaExtension(ext)) {
        mediaLike++;
        continue;
      }
      if (ext.isEmpty && entry.length > 1024) mediaLike++;
    }
    return mediaLike > 0;
  }

  Future<void> _searchForStatuses(String uri, List<String> found, {required int depth}) async {
    if (depth > 6 || found.isNotEmpty) return;

    final entries = await _safUtil.list(uri);
    for (final entry in entries) {
      if (!entry.isDir) continue;

      final name = entry.name.toLowerCase();
      if (name == '.statuses') {
        found.add(entry.uri);
        return;
      }

      if (_shouldTraverse(name)) {
        await _searchForStatuses(entry.uri, found, depth: depth + 1);
        if (found.isNotEmpty) return;
      }
    }
  }

  bool _shouldTraverse(String folderName) => {
        'android',
        'media',
        'whatsapp',
        'whatsapp business',
        'com.whatsapp',
        'com.whatsapp.w4b',
      }.contains(folderName);

  Future<Directory> _cacheDirectory(WhatsAppVariant variant) async {
    final appCacheDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appCacheDir.path, 'status_cache', variant.name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _idFor(WhatsAppVariant variant, String name, int size) =>
      sha1.convert(utf8.encode('${variant.name}:$name:$size')).toString();
}

class _ResolvedMedia {
  final StatusMediaType type;
  final String extension;
  const _ResolvedMedia(this.type, this.extension);
}
