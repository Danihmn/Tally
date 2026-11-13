import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/storage/session_token_store.dart';
import 'package:mobile/features/auth/domain/usecases/login.dart';
import 'package:mobile/features/auth/presentation/viewmodels/login_view_model.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fakes.dart';

void main() {
  late FakeAuthRepository repository;
  late SessionExpiredNotifier notifier;
  late SessionController session;
  late LoginViewModel viewModel;

  setUp(() {
    repository = FakeAuthRepository();
    notifier = SessionExpiredNotifier();
    session = SessionController(
      tokenStore: SessionTokenStore(FakeSecureStorage()),
      expiredNotifier: notifier,
    );
    viewModel = LoginViewModel(login: Login(repository), session: session);
  });

  tearDown(() async {
    viewModel.dispose();
    session.dispose();
    await notifier.dispose();
  });

  group('LoginViewModel.submit', () {
    test('empty_fields_make_no_request_and_say_so', () async {
      await viewModel.submit(email: '  ', password: '');

      expect(viewModel.missingFields, isTrue);
      expect(repository.logins, isEmpty);
    });

    test('an_empty_password_alone_is_also_missing', () async {
      await viewModel.submit(email: 'ana@casa.com', password: '');

      expect(viewModel.missingFields, isTrue);
      expect(repository.logins, isEmpty);
    });

    test('a_successful_login_opens_the_session', () async {
      await viewModel.submit(email: 'ana@casa.com', password: 'segredo123');

      expect(session.isLoggedIn, isTrue);
      expect(viewModel.failure, isNull);
      expect(viewModel.missingFields, isFalse);
    });

    test('the_email_is_trimmed_and_the_password_is_not', () async {
      await viewModel.submit(email: '  ana@casa.com ', password: ' segredo ');

      expect(repository.logins.single.email, 'ana@casa.com');
      expect(repository.logins.single.password, ' segredo ');
    });

    test(
      'wrong_credentials_keep_the_session_closed_and_show_the_failure',
      () async {
        repository.answer = const Result<void>.failure(UnauthorizedFailure());

        await viewModel.submit(email: 'ana@casa.com', password: 'errada');

        expect(session.isLoggedIn, isFalse);
        expect(viewModel.failure, const UnauthorizedFailure());
      },
    );

    test('it_is_busy_while_the_request_runs', () async {
      repository.pending = Completer<Result<void>>();

      final future = viewModel.submit(email: 'ana@casa.com', password: 'x1');
      expect(viewModel.busy, isTrue);

      repository.pending!.complete(const Result<void>.success(null));
      await future;

      expect(viewModel.busy, isFalse);
    });

    test('a_second_submit_while_busy_is_ignored', () async {
      repository.pending = Completer<Result<void>>();

      final first = viewModel.submit(email: 'ana@casa.com', password: 'x1');
      await viewModel.submit(email: 'ana@casa.com', password: 'x1');
      repository.pending!.complete(const Result<void>.success(null));
      await first;

      expect(repository.logins, hasLength(1));
    });

    test('a_new_attempt_clears_the_previous_failure', () async {
      repository.answer = const Result<void>.failure(UnauthorizedFailure());
      await viewModel.submit(email: 'ana@casa.com', password: 'errada');
      repository.answer = const Result<void>.success(null);

      await viewModel.submit(email: 'ana@casa.com', password: 'certa123');

      expect(viewModel.failure, isNull);
    });

    test('it_can_be_disposed_while_the_request_runs', () async {
      repository.pending = Completer<Result<void>>();

      final future = viewModel.submit(email: 'ana@casa.com', password: 'x1');
      viewModel.dispose();
      repository.pending!.complete(const Result<void>.success(null));

      await expectLater(future, completes);
      // The tearDown disposes it again: build a fresh one for it.
      viewModel = LoginViewModel(login: Login(repository), session: session);
    });
  });

  group('LoginViewModel.clearError', () {
    test('hides_the_failure_and_the_missing_fields_notice', () async {
      await viewModel.submit(email: '', password: '');
      expect(viewModel.missingFields, isTrue);

      viewModel.clearError();

      expect(viewModel.missingFields, isFalse);
    });

    test('does_not_notify_when_there_is_nothing_to_clear', () {
      var calls = 0;
      viewModel
        ..addListener(() => calls++)
        ..clearError();

      expect(calls, 0);
    });
  });
}
