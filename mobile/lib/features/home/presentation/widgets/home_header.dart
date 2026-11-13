import 'package:material_ui/material_ui.dart';
import 'package:mobile/l10n/app_localizations.dart';

enum _ProfileAction { logout }

/// Greeting, the refresh button and the avatar with the menu.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.name,
    required this.initial,
    required this.onRefresh,
    required this.onLogout,
  });

  final String name;
  final String initial;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

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
              Text(
                l10n.homeGreeting(name),
                style: theme.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
          onSelected: (_) => onLogout(),
          itemBuilder: (context) => [
            PopupMenuItem<_ProfileAction>(
              value: _ProfileAction.logout,
              child: Text(l10n.homeLogout),
            ),
          ],
          child: CircleAvatar(radius: 22, child: Text(initial)),
        ),
      ],
    );
  }
}
