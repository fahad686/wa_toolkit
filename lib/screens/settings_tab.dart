import 'package:flutter/material.dart';
import '../app/bootstrap.dart';
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
  bool _hasDecoyPin = false;
  bool _biometric = false;
  bool _canBio = false;
  bool _regularAccess = false;
  bool _businessAccess = false;
  bool _autoSave = false;
  bool _autoSaveVideosOnly = false;
  bool _promptVault = false;
  bool _deletedAlerts = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = AppServices.I;
    final hasPin = await widget.vault.hasPin();
    final hasDecoy = await widget.vault.hasDecoyPin();
    final bio = await widget.vault.isBiometricEnabled();
    final canBio = await widget.vault.canUseBiometric();
    final regular = await widget.scanner.hasAccess(WhatsAppVariant.regular);
    final business = await widget.scanner.hasAccess(WhatsAppVariant.business);
    setState(() {
      _hasPin = hasPin;
      _hasDecoyPin = hasDecoy;
      _biometric = bio;
      _canBio = canBio;
      _regularAccess = regular;
      _businessAccess = business;
      _autoSave = s.prefs.autoSaveEnabled;
      _autoSaveVideosOnly = s.prefs.autoSaveVideosOnly;
      _promptVault = s.prefs.promptVaultAfterSave;
      _deletedAlerts = s.prefs.deletedAlertsEnabled;
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

  Future<void> _setupDecoyPin() async {
    final pin = await _pinDialog('Set decoy PIN');
    if (pin == null) return;
    await widget.vault.setDecoyPin(pin);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Decoy PIN set')));
    }
  }

  Future<String?> _pinDialog(String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'PIN (4-6 digits)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.length < 4) return;
              Navigator.pop(ctx, controller.text);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppServices.I.prefs;

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
        const Text('Auto-save', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SwitchListTile(
          title: const Text('Auto-save new statuses'),
          subtitle: const Text('Automatically save statuses when scanned'),
          value: _autoSave,
          onChanged: (v) async {
            await prefs.setAutoSaveEnabled(v);
            setState(() => _autoSave = v);
          },
        ),
        SwitchListTile(
          title: const Text('Videos only'),
          value: _autoSaveVideosOnly,
          onChanged: !_autoSave
              ? null
              : (v) async {
                  await prefs.setAutoSaveVideosOnly(v);
                  setState(() => _autoSaveVideosOnly = v);
                },
        ),
        SwitchListTile(
          title: const Text('Prompt to move to vault after save'),
          value: _promptVault,
          onChanged: (v) async {
            await prefs.setPromptVaultAfterSave(v);
            setState(() => _promptVault = v);
          },
        ),
        const Divider(height: 32),
        const Text('Deleted messages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SwitchListTile(
          title: const Text('Deleted message alerts'),
          subtitle: const Text('Notify when a deleted message is captured'),
          value: _deletedAlerts,
          onChanged: (v) async {
            await prefs.setDeletedAlertsEnabled(v);
            setState(() => _deletedAlerts = v);
          },
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
          leading: const Icon(Icons.security),
          title: Text(_hasDecoyPin ? 'Decoy PIN enabled' : 'Set decoy PIN'),
          subtitle: const Text('Opens an empty vault if someone enters the decoy PIN'),
          trailing: _hasDecoyPin
              ? TextButton(
                  onPressed: () async {
                    await widget.vault.clearDecoyPin();
                    await _load();
                  },
                  child: const Text('Remove'),
                )
              : null,
          onTap: _hasDecoyPin ? null : _setupDecoyPin,
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
