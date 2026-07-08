import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VaultUnlockPanel extends StatefulWidget {
  final bool hasPin;
  final bool canUseBiometric;
  final bool biometricEnabled;
  final Duration? lockoutRemaining;
  final Future<void> Function() onSetupPin;
  final Future<bool> Function(String pin) onUnlockPin;
  final Future<void> Function() onUnlockBiometric;
  final VaultLockScreenStats? stats;

  const VaultUnlockPanel({
    super.key,
    required this.hasPin,
    required this.canUseBiometric,
    required this.biometricEnabled,
    required this.onSetupPin,
    required this.onUnlockPin,
    required this.onUnlockBiometric,
    this.lockoutRemaining,
    this.stats,
  });

  @override
  State<VaultUnlockPanel> createState() => _VaultUnlockPanelState();
}

class VaultLockScreenStats {
  final int items;
  final String storageLabel;
  final int folders;

  const VaultLockScreenStats({required this.items, required this.storageLabel, required this.folders});
}

class _VaultUnlockPanelState extends State<VaultUnlockPanel> {
  final _pin = <String>[];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.hasPin && widget.biometricEnabled && widget.canUseBiometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBio());
    }
  }

  Future<void> _tryBio() async {
    if (widget.lockoutRemaining != null) return;
    setState(() => _busy = true);
    try {
      await widget.onUnlockBiometric();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _tapDigit(String d) {
    if (_busy || widget.lockoutRemaining != null) return;
    if (_pin.length >= 6) return;
    setState(() {
      _pin.add(d);
      _error = null;
    });
    if (_pin.length >= 4) _submit();
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin.removeLast());
  }

  Future<void> _submit() async {
    if (_pin.length < 4) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.onUnlockPin(_pin.join());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) {
        _error = 'Wrong PIN';
        _pin.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!widget.hasPin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 72, color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'Secure Vault',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'AES-encrypted storage with PIN, fingerprint, decoy mode, private notes, and folders.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : () async {
                  setState(() => _busy = true);
                  await widget.onSetupPin();
                  if (mounted) setState(() => _busy = false);
                },
                icon: const Icon(Icons.pin_outlined),
                label: const Text('Set up vault PIN'),
              ),
            ],
          ),
        ),
      );
    }

    final lockout = widget.lockoutRemaining;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.lock_rounded, size: 56, color: cs.primary),
          const SizedBox(height: 12),
          const Text('Vault locked', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          if (widget.stats != null) ...[
            const SizedBox(height: 8),
            Text(
              '${widget.stats!.items} items · ${widget.stats!.storageLabel} · ${widget.stats!.folders} folders',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],
          if (lockout != null) ...[
            const SizedBox(height: 12),
            Text(
              'Try again in ${lockout.inSeconds}s',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              6,
              (i) => Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? cs.primary : cs.surfaceContainerHighest,
                  border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ],
          const SizedBox(height: 16),
          if (widget.biometricEnabled && widget.canUseBiometric)
            IconButton(
              iconSize: 48,
              onPressed: _busy || lockout != null ? null : _tryBio,
              icon: Icon(Icons.fingerprint, color: cs.primary),
            ),
          _PinPad(
            onDigit: _tapDigit,
            onBackspace: _backspace,
            disabled: _busy || lockout != null,
          ),
          if (_busy) const Padding(
            padding: EdgeInsets.only(top: 16),
            child: CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final bool disabled;

  const _PinPad({
    required this.onDigit,
    required this.onBackspace,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final k = keys[i];
        if (k.isEmpty) return const SizedBox.shrink();
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: disabled
                ? null
                : () {
                    if (k == '⌫') {
                      onBackspace();
                    } else {
                      onDigit(k);
                    }
                  },
            child: Center(
              child: Text(k, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
            ),
          ),
        );
      },
    );
  }
}
