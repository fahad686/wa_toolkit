import 'package:flutter/material.dart';
import '../../../../app/bootstrap.dart';
import '../../../../services/whatsapp_paths.dart';
import '../data/models/captured_message.dart';
import 'message_detail_screen.dart';
import 'widgets/message_tile.dart';

class DeletedMessagesScreen extends StatefulWidget {
  const DeletedMessagesScreen({super.key});

  @override
  State<DeletedMessagesScreen> createState() => _DeletedMessagesScreenState();
}

class _DeletedMessagesScreenState extends State<DeletedMessagesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _hasPermission = false;
  bool _loading = true;
  bool _showSavedOnly = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _checkPermission();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final granted = await AppServices.I.notificationCapture.hasPermission();
    setState(() {
      _hasPermission = granted;
      _loading = false;
    });
  }

  Future<void> _requestPermission() async {
    await AppServices.I.notificationCapture.requestPermission();
    await AppServices.I.notificationCapture.start();
    await _checkPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted Messages'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'WhatsApp'),
            Tab(text: 'Business'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _showSavedOnly ? 'Show all' : 'Show saved only',
            icon: Icon(_showSavedOnly ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () => setState(() => _showSavedOnly = !_showSavedOnly),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasPermission
              ? _PermissionPrompt(onGrant: _requestPermission)
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _MessageList(variant: WhatsAppVariant.regular, savedOnly: _showSavedOnly),
                    _MessageList(variant: WhatsAppVariant.business, savedOnly: _showSavedOnly),
                  ],
                ),
    );
  }
}

class _PermissionPrompt extends StatelessWidget {
  final VoidCallback onGrant;
  const _PermissionPrompt({required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_active_outlined, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Enable notification access to capture WhatsApp messages.\n\n'
            'When someone sends a message (or deletes it), we save a copy from '
            'the notification — WhatsApp does not allow reading deleted chats directly.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onGrant,
            icon: const Icon(Icons.settings),
            label: const Text('Grant notification access'),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatefulWidget {
  final WhatsAppVariant variant;
  final bool savedOnly;

  const _MessageList({required this.variant, required this.savedOnly});

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  @override
  Widget build(BuildContext context) {
    final store = AppServices.I.messages;
    final items = widget.savedOnly
        ? store.all(variant: widget.variant, savedOnly: true)
        : store.all(variant: widget.variant);

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.savedOnly
                ? 'No saved messages for ${widget.variant.shortLabel}.'
                : 'No captured messages yet.\n\n'
                    'New WhatsApp notifications will appear here automatically.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final msg = items[index];
          return MessageTile(
            message: msg,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MessageDetailScreen(message: msg)),
            ).then((_) => setState(() {})),
            onSave: () async {
              await store.saveMessage(msg);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Saved message from ${msg.senderName}')),
                );
              }
              setState(() {});
            },
          );
        },
      ),
    );
  }
}
