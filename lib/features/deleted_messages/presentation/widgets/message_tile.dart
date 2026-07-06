import 'package:flutter/material.dart';
import '../../../../utils/format_utils.dart';
import '../../data/models/captured_message.dart';

class MessageTile extends StatelessWidget {
  final CapturedMessage message;
  final VoidCallback onTap;
  final VoidCallback onSave;

  const MessageTile({
    super.key,
    required this.message,
    required this.onTap,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Text(message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?'),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              message.senderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (message.isSaved) const Icon(Icons.bookmark, size: 16, color: Colors.green),
          if (message.isLikelyDeleted)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.content, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(formatDateTime(message.capturedAt), style: const TextStyle(fontSize: 11)),
        ],
      ),
      trailing: Tooltip(
        message: 'Save message',
        triggerMode: TooltipTriggerMode.longPress,
        child: IconButton(
          icon: const Icon(Icons.bookmark_add_outlined),
          onPressed: onSave,
        ),
      ),
    );
  }
}
