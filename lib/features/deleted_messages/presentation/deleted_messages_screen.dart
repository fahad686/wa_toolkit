import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../app/bootstrap.dart';
import '../../../../services/whatsapp_paths.dart';
import '../data/models/captured_message.dart';
import 'conversation_thread_screen.dart';
import 'message_detail_screen.dart';
import 'widgets/message_tile.dart';

enum _MessageView { list, chats }

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
  bool _deletedOnly = false;
  bool _groupsOnly = false;
  _MessageView _view = _MessageView.list;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _checkPermission();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
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

  Future<void> _exportMessages(List<CapturedMessage> items) async {
    if (items.isEmpty) return;
    final text = AppServices.I.messages.exportText(items);
    await Share.share(text, subject: 'Exported WhatsApp messages');
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
            tooltip: _view == _MessageView.chats ? 'List view' : 'Chat view',
            icon: Icon(_view == _MessageView.chats ? Icons.view_list : Icons.forum_outlined),
            onPressed: () => setState(() {
              _view = _view == _MessageView.chats ? _MessageView.list : _MessageView.chats;
            }),
          ),
          IconButton(
            tooltip: 'Export visible',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () {
              final variant = _tabs.index == 0 ? WhatsAppVariant.regular : WhatsAppVariant.business;
              final items = _filteredItems(variant);
              _exportMessages(items);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) => setState(() {
              switch (v) {
                case 'saved':
                  _showSavedOnly = !_showSavedOnly;
                case 'deleted':
                  _deletedOnly = !_deletedOnly;
                case 'groups':
                  _groupsOnly = !_groupsOnly;
              }
            }),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'saved',
                checked: _showSavedOnly,
                child: const Text('Saved only'),
              ),
              CheckedPopupMenuItem(
                value: 'deleted',
                checked: _deletedOnly,
                child: const Text('Deleted only'),
              ),
              CheckedPopupMenuItem(
                value: 'groups',
                checked: _groupsOnly,
                child: const Text('Groups only'),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasPermission
              ? _PermissionPrompt(onGrant: _requestPermission)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search messages…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _MessagePane(
                            variant: WhatsAppVariant.regular,
                            view: _view,
                            items: _filteredItems(WhatsAppVariant.regular),
                            onExport: _exportMessages,
                          ),
                          _MessagePane(
                            variant: WhatsAppVariant.business,
                            view: _view,
                            items: _filteredItems(WhatsAppVariant.business),
                            onExport: _exportMessages,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  List<CapturedMessage> _filteredItems(WhatsAppVariant variant) {
    return AppServices.I.messages.filtered(
      variant: variant,
      savedOnly: _showSavedOnly ? true : null,
      deletedOnly: _deletedOnly ? true : null,
      groupsOnly: _groupsOnly ? true : null,
      query: _query,
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

class _MessagePane extends StatefulWidget {
  final WhatsAppVariant variant;
  final _MessageView view;
  final List<CapturedMessage> items;
  final Future<void> Function(List<CapturedMessage>) onExport;

  const _MessagePane({
    required this.variant,
    required this.view,
    required this.items,
    required this.onExport,
  });

  @override
  State<_MessagePane> createState() => _MessagePaneState();
}

class _MessagePaneState extends State<_MessagePane> {
  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No messages match your filters for ${widget.variant.shortLabel}.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (widget.view == _MessageView.chats) {
      final grouped = <String, List<CapturedMessage>>{};
      for (final msg in widget.items) {
        grouped.putIfAbsent(msg.senderName, () => []).add(msg);
      }
      final senders = grouped.keys.toList()
        ..sort((a, b) => grouped[b]!.first.capturedAt.compareTo(grouped[a]!.first.capturedAt));

      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: senders.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final sender = senders[index];
          final msgs = grouped[sender]!;
          final latest = msgs.first;
          return ListTile(
            leading: CircleAvatar(child: Text(sender.isNotEmpty ? sender[0].toUpperCase() : '?')),
            title: Text(sender, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(latest.content, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text('${msgs.length}'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConversationThreadScreen(senderName: sender, messages: msgs),
              ),
            ),
          );
        },
      );
    }

    final store = AppServices.I.messages;
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: widget.items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final msg = widget.items[index];
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
