import 'package:flutter/material.dart';
import '../services/file_repair_service.dart';
import '../services/gallery_service.dart';
import '../services/local_cache_service.dart';
import '../services/share_service.dart';
import '../services/status_scanner_service.dart';
import '../services/whatsapp_paths.dart';
import 'whatsapp_variant_tab.dart';

class StatusesHomeScreen extends StatefulWidget {
  final LocalCacheService cache;
  final StatusScannerService scanner;
  final GalleryService gallery;
  final ShareService share;
  final FileRepairService repair;

  const StatusesHomeScreen({
    super.key,
    required this.cache,
    required this.scanner,
    required this.gallery,
    required this.share,
    required this.repair,
  });

  @override
  State<StatusesHomeScreen> createState() => StatusesHomeScreenState();
}

class StatusesHomeScreenState extends State<StatusesHomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _regularKey = GlobalKey<WhatsAppVariantTabState>();
  final _businessKey = GlobalKey<WhatsAppVariantTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void reloadAll() {
    _regularKey.currentState?.reload();
    _businessKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.chat), text: 'WhatsApp'),
              Tab(icon: Icon(Icons.business), text: 'Business'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              WhatsAppVariantTab(
                key: _regularKey,
                variant: WhatsAppVariant.regular,
                cache: widget.cache,
                scanner: widget.scanner,
                gallery: widget.gallery,
                share: widget.share,
                repair: widget.repair,
              ),
              WhatsAppVariantTab(
                key: _businessKey,
                variant: WhatsAppVariant.business,
                cache: widget.cache,
                scanner: widget.scanner,
                gallery: widget.gallery,
                share: widget.share,
                repair: widget.repair,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
