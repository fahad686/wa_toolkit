import 'package:flutter/material.dart';
import '../services/whatsapp_paths.dart';

class WhatsAppAccessGuide extends StatefulWidget {
  final WhatsAppVariant variant;
  final VoidCallback onGrantAccess;
  final bool hasAccess;

  const WhatsAppAccessGuide({
    super.key,
    required this.variant,
    required this.onGrantAccess,
    required this.hasAccess,
  });

  @override
  State<WhatsAppAccessGuide> createState() => _WhatsAppAccessGuideState();
}

class _WhatsAppAccessGuideState extends State<WhatsAppAccessGuide> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final guide = WhatsAppGuide(widget.variant);
    final color = widget.variant == WhatsAppVariant.business ? Colors.teal : Colors.green;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(
          widget.variant == WhatsAppVariant.business ? Icons.business : Icons.chat,
          size: 56,
          color: color,
        ),
        const SizedBox(height: 12),
        Text(
          guide.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (widget.hasAccess)
          Chip(
            avatar: const Icon(Icons.check_circle, color: Colors.green, size: 18),
            label: Text('${widget.variant.shortLabel} folder access granted'),
          )
        else
          Chip(
            avatar: Icon(Icons.warning_amber, color: Colors.orange.shade800, size: 18),
            label: const Text('Folder access required'),
          ),
        const SizedBox(height: 16),
        Card(
          child: ExpansionTile(
            initiallyExpanded: _expanded,
            onExpansionChanged: (v) => setState(() => _expanded = v),
            title: const Text('Step-by-step guide'),
            subtitle: Text(WhatsAppPaths.humanPathFor(widget.variant)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < guide.steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: color)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(guide.steps[i])),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Folder path', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText(
                  WhatsAppPaths.humanPathFor(widget.variant),
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick capture tip', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'If someone posts and deletes a status quickly, keep this app open in the '
                  'background. It scans every 20 seconds and saves a copy before WhatsApp removes it.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: widget.onGrantAccess,
          icon: const Icon(Icons.folder_open),
          label: Text('Grant ${widget.variant.shortLabel} folder access'),
        ),
        const SizedBox(height: 12),
        ...guide.tips.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(child: Text(t, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
