import 'package:flutter/material.dart';

class VaultUnlockPanel extends StatefulWidget {
  final bool hasPin;
  final bool canUseBiometric;
  final bool biometricEnabled;
  final Duration? lockoutRemaining;
  final Future<bool> Function(String pin) onSetupPin;
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
  static const _pinLength = 4;

  final _pin = <String>[];
  bool _busy = false;
  String? _error;
  String? _setupDraft;
  bool _confirmSetup = false;

  @override
  void initState() {
    super.initState();
    if (widget.hasPin && widget.biometricEnabled && widget.canUseBiometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBio());
    }
  }

  @override
  void didUpdateWidget(covariant VaultUnlockPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.hasPin && widget.hasPin) {
      _setupDraft = null;
      _confirmSetup = false;
      _pin.clear();
      _error = null;
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
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin.add(d);
      _error = null;
    });
    if (_pin.length == _pinLength) _submit();
  }

  void _backspace() {
    if (_pin.isEmpty || _busy) return;
    setState(() => _pin.removeLast());
  }

  Future<void> _submit() async {
    if (_pin.length != _pinLength) return;
    final entered = _pin.join();

    setState(() {
      _busy = true;
      _error = null;
    });

    bool ok;
    if (!widget.hasPin) {
      if (!_confirmSetup) {
        setState(() {
          _busy = false;
          _setupDraft = entered;
          _confirmSetup = true;
          _pin.clear();
        });
        return;
      }

      if (entered != _setupDraft) {
        setState(() {
          _busy = false;
          _error = 'PINs do not match. Start again.';
          _setupDraft = null;
          _confirmSetup = false;
          _pin.clear();
        });
        return;
      }

      ok = await widget.onSetupPin(entered);
    } else {
      ok = await widget.onUnlockPin(entered);
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) {
        _error = widget.hasPin ? 'Wrong PIN' : 'Could not create PIN. Try again.';
        _pin.clear();
        if (!widget.hasPin) {
          _setupDraft = null;
          _confirmSetup = false;
        }
      }
    });
  }

  String get _title {
    if (!widget.hasPin) {
      return _confirmSetup ? 'Confirm your PIN' : 'Create vault PIN';
    }
    return 'Vault locked';
  }

  String get _subtitle {
    if (!widget.hasPin) {
      return _confirmSetup
          ? 'Enter the same 4-digit PIN again'
          : 'Choose a 4-digit PIN to protect your vault';
    }
    return 'Enter your 4-digit PIN';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lockout = widget.lockoutRemaining;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            widget.hasPin ? Icons.lock_rounded : Icons.shield_outlined,
            size: 56,
            color: cs.primary,
          ),
          const SizedBox(height: 12),
          Text(_title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            _subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
          if (widget.hasPin && widget.stats != null) ...[
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
              _pinLength,
              (i) => Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 8),
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
          if (widget.hasPin && widget.biometricEnabled && widget.canUseBiometric)
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
          if (_busy)
            const Padding(
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
