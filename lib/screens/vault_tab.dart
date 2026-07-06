import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/status_item.dart';
import '../services/gallery_service.dart';
import '../services/local_cache_service.dart';
import '../services/share_service.dart';
import '../services/vault_service.dart';
import '../services/status_actions_runner.dart';
import '../widgets/status_grid.dart';
import 'status_viewer_screen.dart';

class VaultTab extends StatefulWidget {
  final LocalCacheService cache;
  final GalleryService gallery;
  final ShareService share;
  final VaultService vault;

  const VaultTab({
    super.key,
    required this.cache,
    required this.gallery,
    required this.share,
    required this.vault,
  });

  @override
  State<VaultTab> createState() => _VaultTabState();
}

class _VaultTabState extends State<VaultTab> {
  List<StatusItem> _items = [];
  bool _checking = true;
  bool _hasPin = false;
  bool _unlocked = false;
  String? _selectedFolder;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _hasPin = await widget.vault.hasPin();
    _unlocked = widget.vault.isUnlocked;
    _refresh();
    setState(() => _checking = false);
  }

  void _refresh() {
    if (widget.vault.isDecoySession) {
      setState(() => _items = []);
      return;
    }
    setState(() => _items = widget.cache.getVaultedInFolder(_selectedFolder));
  }

  StatusActionsRunner _actionsRunner() => StatusActionsRunner(
        context: context,
        cache: widget.cache,
        gallery: widget.gallery,
        shareService: widget.share,
        onChanged: _refresh,
      );

  void _openViewer(StatusItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusViewerScreen(
          item: item,
          items: _items,
          initialIndex: _items.indexOf(item),
          cache: widget.cache,
          gallery: widget.gallery,
          share: widget.share,
          onChanged: _refresh,
        ),
      ),
    );
  }

  Future<void> _setupPin() async {
    final pin = await _pinDialog(title: 'Create vault PIN', confirm: true);
    if (pin == null) return;
    await widget.vault.setPin(pin);
    widget.vault.lock();
    setState(() {
      _hasPin = true;
      _unlocked = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vault PIN created')));
    }
  }

  Future<void> _unlock() async {
    if (!widget.vault.isDecoySession &&
        await widget.vault.isBiometricEnabled() &&
        await widget.vault.canUseBiometric()) {
      final bioOk = await widget.vault.unlockWithBiometric();
      if (bioOk) {
        setState(() => _unlocked = true);
        _refresh();
        return;
      }
    }

    final pin = await _pinDialog(title: 'Enter vault PIN');
    if (pin == null) return;
    var ok = await widget.vault.verifyPin(pin);
    if (!ok) ok = await widget.vault.verifyDecoyPin(pin);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wrong PIN')));
      return;
    }
    setState(() => _unlocked = ok);
    _refresh();
  }

  Future<String?> _pinDialog({required String title, bool confirm = false}) async {
    final controller = TextEditingController();
    final confirmController = confirm ? TextEditingController() : null;

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              decoration: const InputDecoration(labelText: 'PIN'),
            ),
            if (confirm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.length < 4) return;
              if (confirm && controller.text != confirmController!.text) return;
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
    if (_checking) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasPin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Secure vault hides sensitive statuses behind a PIN or fingerprint.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _setupPin, child: const Text('Set up vault PIN')),
            ],
          ),
        ),
      );
    }

    if (!_unlocked) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 64),
              const SizedBox(height: 16),
              const Text('Vault is locked', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              FilledButton(onPressed: _unlock, child: const Text('Unlock')),
            ],
          ),
        ),
      );
    }

    if (widget.vault.isDecoySession) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Vault is empty.', textAlign: TextAlign.center),
        ),
      );
    }

    final folders = widget.cache.vaultFolders();

    return Column(
      children: [
        if (folders.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedFolder == null,
                  onSelected: (_) => setState(() {
                    _selectedFolder = null;
                    _refresh();
                  }),
                ),
                const SizedBox(width: 6),
                ...folders.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(f),
                      selected: _selectedFolder == f,
                      onSelected: (_) => setState(() {
                        _selectedFolder = f;
                        _refresh();
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Vault is empty.\nTap the lock icon on any status to move it here.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : StatusGrid(
                  items: _items,
                  onTap: _openViewer,
                  actionsRunner: _actionsRunner(),
                  gallery: widget.gallery,
                ),
        ),
      ],
    );
  }
}
