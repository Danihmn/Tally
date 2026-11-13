import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  Future<void> pumpRouter(
    WidgetTester tester, {
    String? Function(BuildContext, Object)? redirect,
  }) {
    final router = createAppRouter(
      home: const SizedBox(),
      login: const SizedBox(),
      redirect: redirect == null
          ? null
          : (context, state) => redirect(context, state),
    );
    return tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(useGoogleFonts: false),
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

  group('app router', () {
    testWidgets('opens_on_home_with_the_five_tabs_of_the_design', (
      tester,
    ) async {
      await pumpRouter(tester);
      await tester.pumpAndSettle();

      final bar = find.byType(NavigationBar);
      for (final label in [
        'Início',
        'Transações',
        'Lançamentos',
        'Contas',
        'Tally IA',
      ]) {
        expect(
          find.descendant(of: bar, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(AppRoutes.home, '/home');
    });

    testWidgets('tapping_a_tab_shows_its_screen', (tester) async {
      await pumpRouter(tester);
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Contas'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Contas')),
        findsOneWidget,
      );
    });
  });
}
