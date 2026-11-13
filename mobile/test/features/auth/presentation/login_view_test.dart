import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/storage/session_token_store.dart';
import 'package:mobile/features/auth/domain/usecases/login.dart';
import 'package:mobile/features/auth/presentation/viewmodels/login_view_model.dart';
import 'package:mobile/features/auth/presentation/views/login_view.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fakes.dart';
import '../../../support/pump_app.dart';

void main() {
  late FakeAuthRepository repository;
  late SessionExpiredNotifier notifier;
  late SessionController session;

  setUp(() {
    repository = FakeAuthRepository();
    notifier = SessionExpiredNotifier();
    session = SessionController(
      tokenStore: SessionTokenStore(FakeSecureStorage()),
      expiredNotifier: notifier,
    );
  });

  tearDown(() async {
    session.dispose();
    await notifier.dispose();
  });

  Future<void> pumpLogin(WidgetTester tester) => pumpApp(
    tester,
    LoginView(
      createViewModel: () =>
          LoginViewModel(login: Login(repository), session: session),
      session: session,
    ),
  );

  Finder field(String label) => find.widgetWithText(TextField, label);

  group('LoginView', () {
    testWidgets('shows_the_title_and_both_fields', (tester) async {
      await pumpLogin(tester);

      expect(find.text('Entre na sua conta'), findsOneWidget);
      expect(field('E-mail'), findsOneWidget);
      expect(field('Senha'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('sends_what_was_typed_when_tapping_enter', (tester) async {
      await pumpLogin(tester);

      await tester.enterText(field('E-mail'), 'ana@casa.com');
      await tester.enterText(field('Senha'), 'segredo123');
      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(repository.logins.single.email, 'ana@casa.com');
      expect(repository.logins.single.password, 'segredo123');
      expect(session.isLoggedIn, isTrue);
    });

    testWidgets('empty_fields_show_the_notice_and_send_nothing', (
      tester,
    ) async {
      await pumpLogin(tester);

      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(
        find.text('Digite o e-mail e a senha para entrar.'),
        findsOneWidget,
      );
      expect(repository.logins, isEmpty);
    });

    testWidgets('wrong_credentials_say_wrong_email_or_password', (
      tester,
    ) async {
      repository.answer = const Result<void>.failure(UnauthorizedFailure());
      await pumpLogin(tester);

      await tester.enterText(field('E-mail'), 'ana@casa.com');
      await tester.enterText(field('Senha'), 'errada123');
      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(
        find.text('E-mail ou senha incorretos. Confira e tente de novo.'),
        findsOneWidget,
      );
      // Not the "session expired" text that a 401 means elsewhere.
      expect(find.text('Sua sessão expirou, entre novamente.'), findsNothing);
    });

    testWidgets('an_unavailable_service_shows_the_server_message', (
      tester,
    ) async {
      repository.answer = const Result<void>.failure(
        ServerUnavailableFailure(),
      );
      await pumpLogin(tester);

      await tester.enterText(field('E-mail'), 'ana@casa.com');
      await tester.enterText(field('Senha'), 'segredo123');
      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(
        find.text('Serviço indisponível. Tente novamente em instantes.'),
        findsOneWidget,
      );
    });

    testWidgets('typing_again_hides_the_error', (tester) async {
      repository.answer = const Result<void>.failure(UnauthorizedFailure());
      await pumpLogin(tester);
      await tester.enterText(field('E-mail'), 'ana@casa.com');
      await tester.enterText(field('Senha'), 'errada123');
      await tester.tap(find.text('Entrar'));
      await tester.pump();

      await tester.enterText(field('Senha'), 'errada1234');
      await tester.pump();

      expect(
        find.text('E-mail ou senha incorretos. Confira e tente de novo.'),
        findsNothing,
      );
    });

    testWidgets('the_password_is_hidden_until_the_eye_is_tapped', (
      tester,
    ) async {
      await pumpLogin(tester);
      bool obscured() => tester.widget<TextField>(field('Senha')).obscureText;
      expect(obscured(), isTrue);

      await tester.tap(find.byTooltip('Mostrar senha'));
      await tester.pump();

      expect(obscured(), isFalse);
      expect(find.byTooltip('Ocultar senha'), findsOneWidget);
    });

    testWidgets('an_expired_session_shows_the_warning', (tester) async {
      await session.restore();
      notifier.notifyExpired();
      await pumpLogin(tester);
      await tester.pump();

      expect(find.text('Sua sessão expirou, entre novamente.'), findsOneWidget);
    });

    testWidgets('without_an_expired_session_there_is_no_warning', (
      tester,
    ) async {
      await pumpLogin(tester);

      expect(find.text('Sua sessão expirou, entre novamente.'), findsNothing);
    });
  });
}
