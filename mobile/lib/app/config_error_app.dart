import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/widgets/empty_state.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Shown instead of the app when `API_BASE_URL` is missing or invalid, so the
/// problem is clear at startup and not a silent network error later.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            body: EmptyState(
              icon: Icons.settings_suggest_outlined,
              title: l10n.configErrorTitle,
              message: l10n.configErrorMessage,
            ),
          );
        },
      ),
    );
  }
}
