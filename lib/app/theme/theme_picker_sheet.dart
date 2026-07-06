import 'package:flutter/material.dart';
import 'theme_notifier.dart';

Future<void> showThemePickerSheet(BuildContext context, ThemeNotifier theme) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Theme', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              _ThemeOption(
                icon: Icons.brightness_auto,
                label: 'System',
                selected: theme.mode == ThemeMode.system,
                onTap: () {
                  theme.setMode(ThemeMode.system);
                  Navigator.pop(ctx);
                },
              ),
              _ThemeOption(
                icon: Icons.light_mode,
                label: 'Light',
                selected: theme.mode == ThemeMode.light,
                onTap: () {
                  theme.setMode(ThemeMode.light);
                  Navigator.pop(ctx);
                },
              ),
              _ThemeOption(
                icon: Icons.dark_mode,
                label: 'Dark',
                selected: theme.mode == ThemeMode.dark,
                onTap: () {
                  theme.setMode(ThemeMode.dark);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: selected ? cs.primary : null),
      title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w600 : null)),
      trailing: selected ? Icon(Icons.check_circle, color: cs.primary) : null,
      onTap: onTap,
    );
  }
}
