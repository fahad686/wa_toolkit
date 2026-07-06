import 'package:flutter/material.dart';
import '../../../../utils/format_utils.dart';
import '../data/models/captured_message.dart';
import 'message_detail_screen.dart';

class ConversationThreadScreen extends StatelessWidget {
  final String senderName;
  final List<CapturedMessage> messages;

  const ConversationThreadScreen({
    super.key,
    required this.senderName,
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<CapturedMessage>.from(messages)
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

    return Scaffold(
      appBar: AppBar(title: Text(senderName)),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          final msg = sorted[index];
          return Align(
            alignment: Alignment.centerLeft,
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MessageDetailScreen(message: msg)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg.content),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            formatDateTime(msg.capturedAt),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          if (msg.isLikelyDeleted) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.delete_outline, size: 14, color: Colors.red.shade400),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
