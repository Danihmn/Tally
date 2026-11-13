import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/storage/session_token_store.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../support/fakes.dart';

void main() {
  late FakeSecureStorage storage;
  late SessionExpiredNotifier notifier;
  late SessionController session;

  setUp(() {
    storage = FakeSecureStorage();
    notifier = SessionExpiredNotifier();
    session = SessionController(
      tokenStore: SessionTokenStore(storage),
      expiredNotifier: notifier,
    );
  });

  tearDown(() async {
    session.dispose();
    await notifier.dispose();
  });

  Future<void> pumpRouter(
    WidgetTester tester, {
    String initialLocation = AppRoutes.home,
  }) async {
    await session.restore();
    final router = createAppRouter(
      home: const Text('HOME-PAGE'),
      login: const Text('LOGIN-PAGE'),
      initialLocation: initialLocation,
      redirect: sessionRedirect(session),
      refreshListenable: session,
    );
    await tester.pumpWidget(
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
    await tester.pumpAndSettle();
  }

  group('session redirect', () {
    testWidgets('without_a_session_the_home_goes_to_the_login', (tester) async {
      await pumpRouter(tester);

      expect(find.text('LOGIN-PAGE'), findsOneWidget);
      expect(find.text('HOME-PAGE'), findsNothing);
    });

    testWidgets('with_a_session_the_home_opens', (tester) async {
      storage.values['auth_token'] = 'jwt';

      await pumpRouter(tester);

      expect(find.text('HOME-PAGE'), findsOneWidget);
    });

    testWidgets('with_a_session_the_login_goes_to_the_home', (tester) async {
      storage.values['auth_token'] = 'jwt';

      await pumpRouter(tester, initialLocation: AppRoutes.login);

      expect(find.text('HOME-PAGE'), findsOneWidget);
      expect(find.text('LOGIN-PAGE'), findsNothing);
    });

    testWidgets('logging_in_moves_from_the_login_to_the_home', (tester) async {
      await pumpRouter(tester);
      expect(find.text('LOGIN-PAGE'), findsOneWidget);

      session.onLoggedIn();
      await tester.pumpAndSettle();

      expect(find.text('HOME-PAGE'), findsOneWidget);
    });

    testWidgets('an_expired_session_sends_the_app_back_to_the_login', (
      tester,
    ) async {
      storage.values['auth_token'] = 'jwt';
      await pumpRouter(tester);
      expect(find.text('HOME-PAGE'), findsOneWidget);

      notifier.notifyExpired();
      await tester.pumpAndSettle();

      expect(find.text('LOGIN-PAGE'), findsOneWidget);
    });

    testWidgets('logging_out_sends_the_app_to_the_login', (tester) async {
      storage.values['auth_token'] = 'jwt';
      await pumpRouter(tester);

      session.onLoggedOut();
      await tester.pumpAndSettle();

      expect(find.text('LOGIN-PAGE'), findsOneWidget);
    });
  });
}
