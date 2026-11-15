import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/theme_controller.dart';
import 'package:mobile/core/widgets/app_bottom_sheet.dart';
import 'package:mobile/core/widgets/filter_fields.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// "Configurações": the theme (light, dark or the device's), the way to the
/// people of the house, and the button to leave.
///
/// The theme is saved by [ThemeController], so it is still there the next time
/// the app opens.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    super.key,
    required this.themeController,
    required this.onOpenUsers,
    required this.onLogout,
  });

  final ThemeController themeController;

  /// Called after the sheet closes, to go to the "Usuários" screen.
  final VoidCallback onOpenUsers;

  /// Called after the sheet closes, to end the session.
  final VoidCallback onLogout;

  static Future<void> show(
    BuildContext context, {
    required ThemeController themeController,
    required VoidCallback onOpenUsers,
    required VoidCallback onLogout,
  }) => showAppBottomSheet<void>(
    context,
    builder: (context) => SettingsSheet(
      themeController: themeController,
      onOpenUsers: onOpenUsers,
      onLogout: onLogout,
    ),
  );

  void _then(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsTitle, style: theme.textTheme.titleLarge),
            FilterSectionLabel(l10n.settingsAppearance),
            ListenableBuilder(
              listenable: themeController,
              builder: (context, _) => SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode_outlined),
                      label: Text(l10n.settingsThemeLight),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode_outlined),
                      label: Text(l10n.settingsThemeDark),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: const Icon(Icons.brightness_auto_outlined),
                      label: Text(l10n.settingsThemeSystem),
                    ),
                  ],
                  selected: {themeController.mode},
                  onSelectionChanged: (values) =>
                      unawaited(themeController.setMode(values.first)),
                ),
              ),
            ),
            FilterSectionLabel(l10n.settingsHousehold),
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _then(context, onOpenUsers),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.group_outlined, color: scheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.settingsUsers,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              l10n.settingsUsersHint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error),
                ),
                onPressed: () => _then(context, onLogout),
                icon: const Icon(Icons.logout_rounded),
                label: Text(l10n.homeLogout),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
