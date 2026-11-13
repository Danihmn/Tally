import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/storage/session_token_store.dart';

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

  group('SessionController', () {
    test('starts_logged_out_until_the_session_is_restored', () {
      expect(session.isLoggedIn, isFalse);
      expect(session.sessionExpired, isFalse);
    });

    test('restore_with_a_stored_token_means_logged_in', () async {
      storage.values['auth_token'] = 'jwt';

      await session.restore();

      expect(session.isLoggedIn, isTrue);
    });

    test('restore_without_a_token_means_logged_out', () async {
      await session.restore();

      expect(session.isLoggedIn, isFalse);
    });

    test('restore_with_an_empty_token_means_logged_out', () async {
      storage.values['auth_token'] = '';

      await session.restore();

      expect(session.isLoggedIn, isFalse);
    });

    test('an_expired_session_logs_out_and_is_remembered', () async {
      storage.values['auth_token'] = 'jwt';
      await session.restore();

      notifier.notifyExpired();
      await pumpEventQueue();

      expect(session.isLoggedIn, isFalse);
      expect(session.sessionExpired, isTrue);
    });

    test('listeners_are_told_when_the_session_expires', () async {
      await session.restore();
      var calls = 0;
      session.addListener(() => calls++);

      notifier.notifyExpired();
      await pumpEventQueue();

      expect(calls, 1);
    });

    test('logging_in_clears_the_expired_flag', () async {
      await session.restore();
      notifier.notifyExpired();
      await pumpEventQueue();

      session.onLoggedIn();

      expect(session.isLoggedIn, isTrue);
      expect(session.sessionExpired, isFalse);
    });

    test('a_second_expiry_after_a_new_login_is_noticed_again', () async {
      await session.restore();
      notifier.notifyExpired();
      await pumpEventQueue();
      session.onLoggedIn();

      notifier.notifyExpired();
      await pumpEventQueue();

      expect(session.isLoggedIn, isFalse);
      expect(session.sessionExpired, isTrue);
    });

    test('logging_out_closes_the_session_without_the_expired_flag', () async {
      storage.values['auth_token'] = 'jwt';
      await session.restore();

      session.onLoggedOut();

      expect(session.isLoggedIn, isFalse);
      expect(session.sessionExpired, isFalse);
    });
  });
}
