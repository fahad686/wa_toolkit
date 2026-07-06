import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/download_task.dart';
import '../models/media_variant.dart';

class DownloadManagerService extends ChangeNotifier {
  static const _boxName = 'download_tasks';

  final Dio _dio = Dio();
  late Box<DownloadTask> _box;
  final Map<String, CancelToken> _cancelTokens = {};

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(DownloadTaskAdapter());
    }
    _box = await Hive.openBox<DownloadTask>(_boxName);
  }

  List<DownloadTask> get all => _box.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<DownloadTask> get active =>
      all.where((t) => t.isActive).toList();

  List<DownloadTask> get completed =>
      all.where((t) => t.status == DownloadStatus.completed).toList();

  List<DownloadTask> byKind(MediaKind kind) =>
      completed.where((t) => t.kind == kind).toList();

  int get completedCount => completed.length;

  Future<DownloadTask> enqueue({
    required String sourceUrl,
    required String title,
    required MediaVariant variant,
  }) async {
    final id = _taskId(sourceUrl, variant);
    if (_box.containsKey(id)) {
      final existing = _box.get(id)!;
      if (existing.status == DownloadStatus.completed && existing.localPath != null) {
        return existing;
      }
      if (existing.isActive) return existing;
    }

    final task = DownloadTask.fromVariant(
      id: id,
      sourceUrl: sourceUrl,
      title: title,
      variant: variant,
    );
    await _box.put(id, task);
    notifyListeners();
    unawaited(_runDownload(task));
    return task;
  }

  Future<void> _runDownload(DownloadTask task) async {
    task.statusIndex = DownloadStatus.downloading.index;
    task.progress = 0;
    task.error = null;
    await task.save();
    notifyListeners();

    final token = CancelToken();
    _cancelTokens[task.id] = token;

    try {
      final path = await _downloadFile(task, token);
      task.localPath = path;
      task.statusIndex = DownloadStatus.completed.index;
      task.progress = 1;
      await task.save();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        task.statusIndex = DownloadStatus.cancelled.index;
      } else {
        task.statusIndex = DownloadStatus.failed.index;
        task.error = e.message ?? 'Download failed';
      }
      await task.save();
    } catch (e) {
      task.statusIndex = DownloadStatus.failed.index;
      task.error = e.toString();
      await task.save();
    } finally {
      _cancelTokens.remove(task.id);
      notifyListeners();
    }
  }

  Future<String> _downloadFile(DownloadTask task, CancelToken token) async {
    final dir = await getApplicationDocumentsDirectory();
    final subfolder = switch (task.kind) {
      MediaKind.video => 'videos',
      MediaKind.audio => 'audio',
      MediaKind.file => 'files',
    };
    final destDir = Directory(p.join(dir.path, 'downloads', subfolder));
    await destDir.create(recursive: true);

    final ext = _extensionFor(task);
    final safeTitle = _safeName(task.title);
    final fileName = '${safeTitle}_${task.variantLabel.replaceAll(RegExp(r'[^\w]+'), '_')}.$ext';
    final destPath = p.join(destDir.path, fileName);

    await _dio.download(
      task.downloadUrl,
      destPath,
      cancelToken: token,
      onReceiveProgress: (received, total) {
        task.progress = total <= 0 ? 0 : received / total;
        task.save();
        notifyListeners();
      },
    );

    return destPath;
  }

  String _extensionFor(DownloadTask task) {
    final label = task.variantLabel.toLowerCase();
    if (label.contains('mp3')) return 'mp3';
    if (label.contains('m4a') || label.contains('aac')) return 'm4a';
    if (label.contains('webm')) return 'webm';
    if (label.contains('m3u8') || label.contains('hls')) return 'ts';
    if (task.kind == MediaKind.audio) return 'm4a';
    if (task.kind == MediaKind.video) return 'mp4';
    return 'dat';
  }

  String _safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
  }

  String _taskId(String sourceUrl, MediaVariant variant) =>
      sha1.convert(utf8.encode('$sourceUrl|${variant.id}')).toString();

  Future<void> cancel(String taskId) async {
    _cancelTokens[taskId]?.cancel();
    final task = _box.get(taskId);
    if (task != null && task.isActive) {
      task.statusIndex = DownloadStatus.cancelled.index;
      await task.save();
      notifyListeners();
    }
  }

  Future<void> retry(String taskId) async {
    final task = _box.get(taskId);
    if (task == null) return;
    task.statusIndex = DownloadStatus.queued.index;
    task.progress = 0;
    task.error = null;
    await task.save();
    notifyListeners();
    unawaited(_runDownload(task));
  }

  Future<void> delete(String taskId) async {
    final task = _box.get(taskId);
    if (task == null) return;
    if (task.localPath != null) {
      final f = File(task.localPath!);
      if (await f.exists()) await f.delete();
    }
    await _box.delete(taskId);
    notifyListeners();
  }

  Future<void> clearCompleted() async {
    for (final task in completed) {
      await delete(task.id);
    }
  }
}
