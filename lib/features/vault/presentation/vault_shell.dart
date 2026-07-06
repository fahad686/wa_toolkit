import 'package:flutter/material.dart';
import '../../../app/bootstrap.dart';
import '../../../screens/vault_tab.dart';

class VaultShell extends StatelessWidget {
  const VaultShell({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppServices.I;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Vault'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: VaultTab(
        cache: s.cache,
        gallery: s.gallery,
        share: s.share,
        vault: s.vault,
      ),
    );
  }
}
