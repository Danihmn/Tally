import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/widgets/ellipsis_text.dart';
import 'package:mobile/l10n/app_localizations.dart';

enum _ProfileAction { settings }

/// Greeting, the refresh button and the avatar with the menu (settings).
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.name,
    required this.initial,
    required this.onRefresh,
    required this.onOpenSettings,
  });

  final String name;
  final String initial;
  final VoidCallback onRefresh;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.appName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              EllipsisText(
                l10n.homeGreeting(name),
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l10n.homeRefresh,
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        PopupMenuButton<_ProfileAction>(
          tooltip: l10n.homeProfileMenu,
          onSelected: (_) => onOpenSettings(),
          itemBuilder: (context) => [
            PopupMenuItem<_ProfileAction>(
              value: _ProfileAction.settings,
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined),
                  const SizedBox(width: 12),
                  Text(l10n.homeSettings),
                ],
              ),
            ),
          ],
          child: CircleAvatar(radius: 22, child: Text(initial)),
        ),
      ],
    );
  }
}
