import 'package:flutter/material.dart';
import '../../../app/bootstrap.dart';
import '../../deleted_messages/presentation/deleted_messages_screen.dart';
import '../../status_saver/presentation/status_saver_shell.dart';
import '../../vault/presentation/vault_shell.dart';
import 'widgets/feature_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppServices.I;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WA Toolkit'),
        actions: [
          IconButton(
            tooltip: 'Theme',
            onPressed: () => s.theme.cycle(),
            icon: Icon(s.theme.icon),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Choose a feature',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Save statuses, recover messages, and secure your media.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            'mef tech',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 20),
          FeatureCard(
            icon: Icons.mark_chat_unread_outlined,
            color: Colors.deepOrange,
            title: 'Deleted Messages',
            subtitle: 'Capture WhatsApp & Business chats from notifications. '
                'View and save before they disappear.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeletedMessagesScreen()),
            ),
          ),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.photo_library_outlined,
            color: cs.primary,
            title: 'Status Saver',
            subtitle: 'Save photos & videos from WhatsApp and WhatsApp Business statuses.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatusSaverShell()),
            ),
          ),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.lock_outline,
            color: Colors.deepPurple,
            title: 'Secure Vault',
            subtitle: 'PIN-protected storage for sensitive statuses and media.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VaultShell()),
            ),
          ),
        ],
      ),
    );
  }
}
