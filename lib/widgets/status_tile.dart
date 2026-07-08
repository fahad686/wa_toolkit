import 'dart:io';
import 'package:flutter/material.dart';
import '../models/status_item.dart';
import '../services/gallery_service.dart';
import '../services/local_cache_service.dart';
import '../services/status_actions_runner.dart';
import '../services/vault_crypto_service.dart';
import '../features/vault/presentation/widgets/vault_media_thumbnail.dart';
import '../utils/format_utils.dart';
import 'status_action_buttons.dart';

class StatusTile extends StatelessWidget {
  final StatusItem item;
  final VoidCallback onTap;
  final StatusActionsRunner? actionsRunner;
  final GalleryService? gallery;
  final LocalCacheService? cache;

  const StatusTile({
    super.key,
    required this.item,
    required this.onTap,
    this.actionsRunner,
    this.gallery,
    this.cache,
  });

  @override
  Widget build(BuildContext context) {
    final fileExists = File(item.displayPath).existsSync();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Thumbnail(item: item, fileExists: fileExists, cache: cache),
                  if (item.deletedFromWhatsApp)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Deleted on WA',
                          style: TextStyle(color: Colors.white, fontSize: 9),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.contactLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                Text(
                  formatDateTime(item.sourceModifiedAt ?? item.discoveredAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(child: _StatusLabel(item: item, fileExists: fileExists)),
                    _TypeIcon(type: item.mediaType),
                  ],
                ),
              ],
            ),
          ),
          if (actionsRunner != null && gallery != null)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: StatusActionButtons(
                item: item,
                runner: actionsRunner!,
                gallery: gallery!,
                compact: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final StatusItem item;
  final bool fileExists;
  final LocalCacheService? cache;

  const _Thumbnail({required this.item, required this.fileExists, this.cache});

  @override
  Widget build(BuildContext context) {
    if (item.isVaulted && cache != null) {
      return VaultMediaThumbnail(item: item, cache: cache!);
    }

    if (!fileExists || item.isMissing) {
      return Container(
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, size: 36),
            SizedBox(height: 4),
            Text('Missing', style: TextStyle(fontSize: 11)),
          ],
        ),
      );
    }

    if (item.mediaType == StatusMediaType.image) {
      final thumb = item.thumbnailPath;
      if (thumb != null && File(thumb).existsSync()) {
        return Image.file(File(thumb), fit: BoxFit.cover);
      }
      if (VaultCryptoService.isEncryptedPath(item.displayPath)) {
        return Container(
          color: Colors.grey.shade300,
          alignment: Alignment.center,
          child: const Icon(Icons.lock_outline, size: 32),
        );
      }
      return Image.file(File(item.displayPath), fit: BoxFit.cover);
    }

    if (item.mediaType == StatusMediaType.video) {
      final thumb = item.thumbnailPath;
      if (thumb != null && File(thumb).existsSync()) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(thumb), fit: BoxFit.cover),
            Container(color: Colors.black26),
            const Center(
              child: Icon(Icons.play_circle_fill, color: Colors.white, size: 44),
            ),
          ],
        );
      }
      return Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 44),
      );
    }

    return Container(
      color: Colors.indigo.shade900,
      alignment: Alignment.center,
      child: const Icon(Icons.audiotrack, color: Colors.white, size: 44),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final StatusItem item;
  final bool fileExists;

  const _StatusLabel({required this.item, required this.fileExists});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    if (!fileExists || item.isMissing) {
      label = 'Needs repair';
      color = Colors.red;
    } else if (item.isVaulted) {
      label = 'In vault';
      color = Colors.deepPurple;
    } else if (item.isSaved) {
      label = 'Saved';
      color = Colors.green;
    } else if (item.deletedFromWhatsApp) {
      label = 'Captured';
      color = Colors.blue;
    } else {
      label = formatDurationRemaining(item.timeRemaining);
      color = Colors.orange;
    }

    return Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500));
  }
}

class _TypeIcon extends StatelessWidget {
  final StatusMediaType type;
  const _TypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      StatusMediaType.image => Icons.image_outlined,
      StatusMediaType.video => Icons.videocam_outlined,
      StatusMediaType.audio => Icons.audiotrack_outlined,
    };
    return Icon(icon, size: 14, color: Colors.grey.shade600);
  }
}
