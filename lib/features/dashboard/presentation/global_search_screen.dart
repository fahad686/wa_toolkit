import 'package:flutter/material.dart';
import '../../../app/bootstrap.dart';
import '../../../features/deleted_messages/data/models/captured_message.dart';
import '../../../features/deleted_messages/presentation/message_detail_screen.dart';
import '../../../models/status_item.dart';
import '../../../screens/status_viewer_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppServices.I;
    final result = s.search.search(_query);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search statuses & messages…',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _query.trim().isEmpty
          ? const Center(child: Text('Type to search across the app'))
          : result.isEmpty
              ? const Center(child: Text('No results'))
              : ListView(
                  children: [
                    if (result.statuses.isNotEmpty) ...[
                      _SectionHeader('Statuses (${result.statuses.length})'),
                      ...result.statuses.map((item) => _StatusResultTile(item: item)),
                    ],
                    if (result.messages.isNotEmpty) ...[
                      _SectionHeader('Messages (${result.messages.length})'),
                      ...result.messages.map((msg) => _MessageResultTile(message: msg)),
                    ],
                  ],
                ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _StatusResultTile extends StatelessWidget {
  final StatusItem item;
  const _StatusResultTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final s = AppServices.I;
    return ListTile(
      leading: Icon(
        switch (item.mediaType) {
          StatusMediaType.image => Icons.image_outlined,
          StatusMediaType.video => Icons.videocam_outlined,
          StatusMediaType.audio => Icons.audiotrack_outlined,
        },
      ),
      title: Text(item.contactLabel),
      subtitle: Text(item.originalFileName ?? 'Status'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StatusViewerScreen(
            item: item,
            items: [item],
            initialIndex: 0,
            cache: s.cache,
            gallery: s.gallery,
            share: s.share,
            repair: s.repair,
          ),
        ),
      ),
    );
  }
}

class _MessageResultTile extends StatelessWidget {
  final CapturedMessage message;
  const _MessageResultTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(message.senderName.isNotEmpty ? message.senderName[0] : '?')),
      title: Text(message.senderName),
      subtitle: Text(message.content, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MessageDetailScreen(message: message)),
      ),
    );
  }
}
