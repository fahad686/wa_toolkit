import 'package:flutter/material.dart';
import '../../../app/bootstrap.dart';
import '../../../app/theme/theme_picker_sheet.dart';
import '../../../services/usage_stats_service.dart';
import '../../../services/whatsapp_paths.dart';
import '../../deleted_messages/presentation/deleted_messages_screen.dart';
import '../../status_saver/presentation/status_saver_shell.dart';
import '../../vault/presentation/vault_shell.dart';
import '../../media_downloader/presentation/media_downloader_shell.dart';
import 'global_search_screen.dart';
import 'widgets/feature_card.dart';
import 'widgets/onboarding_banner.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _syncOnboarding();
  }

  Future<void> _syncOnboarding() async {
    final s = AppServices.I;
    final prefs = s.prefs;
    if (await s.scanner.hasAccess(WhatsAppVariant.regular) ||
        await s.scanner.hasAccess(WhatsAppVariant.business)) {
      await prefs.setOnboardingStatus(true);
    }
    if (await s.notificationCapture.hasPermission()) {
      await prefs.setOnboardingMessages(true);
    }
    if (await s.vault.hasPin()) {
      await prefs.setOnboardingVault(true);
    }
    if (mounted) setState(() {});
  }

  Future<void> _openFeature(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    await _syncOnboarding();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppServices.I;
    final cs = Theme.of(context).colorScheme;
    final stats = s.stats.compute();

    return Scaffold(
      appBar: AppBar(
        title: const Text('WA Toolkit'),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
            ),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Theme',
            onPressed: () async {
              await showThemePickerSheet(context, s.theme);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Theme: ${s.theme.mode.name}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            icon: Icon(s.theme.icon),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Choose a feature', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Save statuses, recover messages, and secure your media.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          GestureDetector(
            onLongPress: () => _openFeature(const VaultShell()),
            child: Text(
              'mef tech',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
            ),
          ),
          const SizedBox(height: 16),
          _StatsRow(stats: stats),
          const SizedBox(height: 16),
          OnboardingBanner(onChanged: () => _syncOnboarding()),
          FeatureCard(
            icon: Icons.mark_chat_unread_outlined,
            color: Colors.deepOrange,
            title: 'Deleted Messages',
            subtitle: 'Capture WhatsApp & Business chats from notifications. '
                'View and save before they disappear.',
            badge: stats.deletedMessages > 0 ? '${stats.deletedMessages} deleted' : null,
            onTap: () => _openFeature(const DeletedMessagesScreen()),
          ),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.photo_library_outlined,
            color: cs.primary,
            title: 'Status Saver',
            subtitle: 'Save photos & videos from WhatsApp and WhatsApp Business statuses.',
            badge: stats.activeStatuses > 0 ? '${stats.activeStatuses} active' : null,
            onTap: () => _openFeature(const StatusSaverShell()),
          ),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.download_outlined,
            color: Colors.teal,
            title: 'Media Downloader',
            subtitle: 'Share or paste a link — pick video quality (360p–4K) or audio and save.',
            badge: stats.downloadCount > 0 ? '${stats.downloadCount} saved' : null,
            onTap: () => _openFeature(const MediaDownloaderShell()),
          ),
          const SizedBox(height: 12),
          if (!s.prefs.vaultHideDashboard)
            FeatureCard(
              icon: Icons.lock_outline,
              color: Colors.deepPurple,
              title: 'Secure Vault',
              subtitle: 'AES-encrypted PIN vault with folders, notes, decoy mode, and auto-lock.',
              badge: stats.vaultedStatuses > 0 ? '${stats.vaultedStatuses} items' : null,
              onTap: () => _openFeature(const VaultShell()),
            ),
          if (!s.prefs.vaultHideDashboard) const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final UsageStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: _StatChip(label: 'Statuses', value: '${stats.activeStatuses}', color: cs.primary)),
        const SizedBox(width: 8),
        Expanded(child: _StatChip(label: 'Messages', value: '${stats.capturedMessages}', color: Colors.deepOrange)),
        const SizedBox(width: 8),
        Expanded(child: _StatChip(label: 'Vault', value: '${stats.vaultedStatuses}', color: Colors.deepPurple)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
