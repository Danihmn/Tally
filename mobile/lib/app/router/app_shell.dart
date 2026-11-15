import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_navigation_bar.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Frame with the bottom navigation. Each tab keeps its own navigation stack.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: navigationShell.currentIndex,
        // Tapping the open tab goes back to its first screen.
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: [
          AppNavigationItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: l10n.navHome,
          ),
          AppNavigationItem(
            icon: Icons.format_list_bulleted,
            label: l10n.navTransactions,
          ),
          AppNavigationItem(
            icon: Icons.event_note_outlined,
            selectedIcon: Icons.event_note,
            label: l10n.navEntries,
          ),
          AppNavigationItem(
            icon: Icons.account_balance_outlined,
            selectedIcon: Icons.account_balance,
            label: l10n.navAccounts,
          ),
          AppNavigationItem(
            icon: Icons.auto_awesome_outlined,
            selectedIcon: Icons.auto_awesome,
            label: l10n.navChat,
          ),
        ],
      ),
    );
  }
}
