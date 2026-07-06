import 'package:flutter/material.dart';
import '../services/status_scanner_service.dart';
import '../services/vault_service.dart';
import '../services/whatsapp_paths.dart';

class SettingsTab extends StatefulWidget {
  final VaultService vault;
  final StatusScannerService scanner;
  final VoidCallback? onFolderAccessChanged;

  const SettingsTab({
    super.key,
    required this.vault,
    required this.scanner,
    this.onFolderAccessChanged,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _hasPin = false;
  bool _biometric = false;
  bool _canBio = false;
  bool _regularAccess = false;
  bool _businessAccess = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hasPin = await widget.vault.hasPin();
    final bio = await widget.vault.isBiometricEnabled();
    final canBio = await widget.vault.canUseBiometric();
    final regular = await widget.scanner.hasAccess(WhatsAppVariant.regular);
    final business = await widget.scanner.hasAccess(WhatsAppVariant.business);
    setState(() {
      _hasPin = hasPin;
      _biometric = bio;
      _canBio = canBio;
      _regularAccess = regular;
      _businessAccess = business;
    });
  }

  Future<void> _regrant(WhatsAppVariant variant) async {
    await widget.scanner.clearFolderAccess(variant);
    final ok = await widget.scanner.requestFolderAccess(variant);
    await _load();
    widget.onFolderAccessChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '${variant.shortLabel} access updated' : 'Cancelled')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Folder access', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ListTile(
          leading: Icon(_regularAccess ? Icons.check_circle : Icons.radio_button_unchecked,
              color: _regularAccess ? Colors.green : Colors.grey),
          title: const Text('WhatsApp'),
          subtitle: Text(WhatsAppPaths.humanReadableRegular),
          trailing: TextButton(onPressed: () => _regrant(WhatsAppVariant.regular), child: const Text('Re-grant')),
        ),
        ListTile(
          leading: Icon(_businessAccess ? Icons.check_circle : Icons.radio_button_unchecked,
              color: _businessAccess ? Colors.green : Colors.grey),
          title: const Text('WhatsApp Business'),
          subtitle: Text(WhatsAppPaths.humanReadableBusiness),
          trailing: TextButton(onPressed: () => _regrant(WhatsAppVariant.business), child: const Text('Re-grant')),
        ),
        const Divider(height: 32),
        const Text('Vault', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SwitchListTile(
          title: const Text('Unlock with fingerprint'),
          value: _biometric && _canBio,
          onChanged: !_hasPin || !_canBio
              ? null
              : (v) async {
                  await widget.vault.setBiometricEnabled(v);
                  setState(() => _biometric = v);
                },
        ),
        ListTile(
          leading: const Icon(Icons.lock_reset),
          title: const Text('Lock vault now'),
          onTap: () {
            widget.vault.lock();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vault locked')));
          },
        ),
        const Divider(height: 32),
        const ListTile(
          leading: Icon(Icons.bolt),
          title: Text('Fast capture'),
          subtitle: Text('Scans every 20 seconds while app is open to save statuses deleted quickly on WhatsApp.'),
        ),
      ],
    );
  }
}
