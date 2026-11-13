import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/theme/theme_controller.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Root widget: theme, pt-BR localization and router.
class TallyApp extends StatelessWidget {
  const TallyApp({
    super.key,
    required this.router,
    required this.themeController,
    this.useGoogleFonts = true,
  });

  final GoRouter router;
  final ThemeController themeController;

  /// False in tests, so they do not download fonts.
  final bool useGoogleFonts;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appName,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: AppTheme.light(useGoogleFonts: useGoogleFonts),
        darkTheme: AppTheme.dark(useGoogleFonts: useGoogleFonts),
        themeMode: themeController.mode,
        locale: const Locale('pt', 'BR'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
