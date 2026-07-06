import 'package:flutter/material.dart';
import '../../../../app/bootstrap.dart';
import '../../../../utils/format_utils.dart';
import '../../../../services/whatsapp_paths.dart';
import '../data/models/captured_message.dart';

class MessageDetailScreen extends StatelessWidget {
  final CapturedMessage message;

  const MessageDetailScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final store = AppServices.I.messages;

    return Scaffold(
      appBar: AppBar(
        title: Text(message.senderName),
        actions: [
          IconButton(
            tooltip: message.isSaved ? 'Already saved' : 'Save message',
            icon: Icon(message.isSaved ? Icons.bookmark : Icons.bookmark_outline),
            onPressed: message.isSaved
                ? null
                : () async {
                    await store.saveMessage(message);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message saved')),
                      );
                      Navigator.pop(context);
                    }
                  },
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await store.deleteMessage(message);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isLikelyDeleted)
              Chip(
                avatar: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Deleted / removed'),
                backgroundColor: Colors.red.shade50,
              ),
            if (message.isSaved)
              const Chip(
                avatar: Icon(Icons.bookmark, size: 16),
                label: Text('Saved'),
              ),
            const SizedBox(height: 12),
            Text('From', style: Theme.of(context).textTheme.labelLarge),
            Text(message.senderName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Time', style: Theme.of(context).textTheme.labelLarge),
            Text(formatDateTime(message.capturedAt)),
            const SizedBox(height: 16),
            Text('App', style: Theme.of(context).textTheme.labelLarge),
            Text(message.variant.label),
            const SizedBox(height: 16),
            Text('Message', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  message.content,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
