import 'package:flutter/material.dart';
import '../../../../app/bootstrap.dart';
import '../../../deleted_messages/presentation/deleted_messages_screen.dart';
import '../../../status_saver/presentation/status_saver_shell.dart';
import '../../../vault/presentation/vault_shell.dart';

class OnboardingBanner extends StatelessWidget {
  final VoidCallback onChanged;

  const OnboardingBanner({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final prefs = AppServices.I.prefs;
    if (prefs.onboardingDone) return const SizedBox.shrink();

    final steps = <_Step>[
      if (!prefs.onboardingStatus)
        _Step(
          icon: Icons.photo_library_outlined,
          title: 'Set up Status Saver',
          subtitle: 'Grant folder access to save WhatsApp statuses.',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatusSaverShell()),
            );
            await prefs.setOnboardingStatus(true);
            onChanged();
          },
        ),
      if (!prefs.onboardingMessages)
        _Step(
          icon: Icons.mark_chat_unread_outlined,
          title: 'Enable Deleted Messages',
          subtitle: 'Allow notification access to capture chats.',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeletedMessagesScreen()),
            );
            await prefs.setOnboardingMessages(true);
            onChanged();
          },
        ),
      if (!prefs.onboardingVault)
        _Step(
          icon: Icons.lock_outline,
          title: 'Create your Vault PIN',
          subtitle: 'Protect sensitive media with a PIN.',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VaultShell()),
            );
            await prefs.setOnboardingVault(true);
            onChanged();
          },
        ),
    ];

    if (steps.isEmpty) {
      prefs.setOnboardingDone(true);
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rocket_launch_outlined),
                const SizedBox(width: 8),
                Text('Get started', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await prefs.setOnboardingDone(true);
                    onChanged();
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...steps.map((step) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(step.icon),
                  title: Text(step.title),
                  subtitle: Text(step.subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: step.onTap,
                )),
          ],
        ),
      ),
    );
  }
}

class _Step {
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onTap;

  const _Step({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
