import 'dart:io';
import '../models/status_item.dart';
import 'local_cache_service.dart';
import 'status_scanner_service.dart';
import 'whatsapp_paths.dart';

class RepairResult {
  final int repaired;
  final int stillMissing;
  final int checked;

  const RepairResult({
    required this.repaired,
    required this.stillMissing,
    required this.checked,
  });
}

class FileRepairService {
  final LocalCacheService _cache;
  final StatusScannerService _scanner;

  FileRepairService(this._cache, this._scanner);

  Future<List<StatusItem>> findMissing() async {
    final missing = <StatusItem>[];
    for (final item in _cache.getAllIncludingMissing()) {
      final path = item.displayPath;
      if (!await File(path).exists()) {
        item.isMissing = true;
        await item.save();
        missing.add(item);
      } else if (item.isMissing) {
        item.isMissing = false;
        await item.save();
      }
    }
    return missing;
  }

  WhatsAppVariant _variantFor(StatusItem item) =>
      item.source == WhatsAppSource.business ? WhatsAppVariant.business : WhatsAppVariant.regular;

  Future<RepairResult> repairAll() async {
    final items = await findMissing();
    if (items.isEmpty) {
      return const RepairResult(repaired: 0, stillMissing: 0, checked: 0);
    }

    int repaired = 0;
    int stillMissing = 0;

    for (final item in items) {
      if (!await _scanner.hasAccess(_variantFor(item))) {
        stillMissing++;
        continue;
      }
      final ok = await _scanner.tryRepairItem(item);
      if (ok) {
        repaired++;
      } else {
        stillMissing++;
      }
    }

    return RepairResult(repaired: repaired, stillMissing: stillMissing, checked: items.length);
  }

  Future<bool> repairOne(StatusItem item) async {
    if (!await _scanner.hasAccess(_variantFor(item))) return false;
    return _scanner.tryRepairItem(item);
  }
}
