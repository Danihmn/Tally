import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/features/auth/data/datasources/auth_remote_data_source.dart';

import '../../../support/fake_dio.dart';
import '../../../support/fakes.dart';

void main() {
  late SessionExpiredNotifier notifier;

  setUp(() => notifier = SessionExpiredNotifier());
  tearDown(() => notifier.dispose());

  AuthRemoteDataSource build(FakeHttpAdapter adapter) =>
      AuthRemoteDataSource(buildFakeDio(adapter, notifier: notifier));

  group('AuthRemoteDataSource.login', () {
    test('posts_the_credentials_to_the_login_endpoint', () async {
      final adapter = FakeHttpAdapter(
        (_) => const FakeReply(200, {
          'access_token': 'jwt-123',
          'token_type': 'bearer',
          'refresh_token': 'refresh-123',
        }),
      );

      final result = await build(adapter)
          .login(email: 'ana@casa.com', password: 'segredo123');

      expect(result.valueOrNull?.accessToken, 'jwt-123');
      expect(result.valueOrNull?.refreshToken, 'refresh-123');
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/auth/login');
      expect(request.data, {'email': 'ana@casa.com', 'password': 'segredo123'});
    });

    test('wrong_credentials_are_an_unauthorized_failure', () async {
      final adapter = FakeHttpAdapter(
        (_) => const FakeReply(401, {'detail': 'Incorrect e-mail or password'}),
      );

      final result = await build(adapter).login(email: 'a@b.c', password: 'x');

      expect(result.failureOrNull, const UnauthorizedFailure());
    });

    test('a_401_on_login_is_not_an_expired_session', () async {
      var expired = 0;
      notifier.stream.listen((_) => expired++);
      final adapter = FakeHttpAdapter((_) => const FakeReply(401, {}));

      await build(adapter).login(email: 'a@b.c', password: 'x');
      await pumpEventQueue();

      expect(expired, 0);
    });

    test('an_unavailable_service_is_a_server_failure', () async {
      final adapter = FakeHttpAdapter((_) => const FakeReply(503, {}));

      final result = await build(adapter).login(email: 'a@b.c', password: 'x');

      expect(result.failureOrNull, const ServerUnavailableFailure());
    });

    test('an_answer_without_a_refresh_token_is_an_unknown_failure', () async {
      final adapter = FakeHttpAdapter(
        (_) => const FakeReply(200, {
          'access_token': 'jwt-123',
          'token_type': 'bearer',
        }),
      );

      final result = await build(adapter).login(email: 'a@b.c', password: 'x');

      expect(result.failureOrNull, const UnknownFailure());
    });

    test('an_answer_without_a_token_is_an_unknown_failure', () async {
      final adapter = FakeHttpAdapter(
        (_) => const FakeReply(200, {'token_type': 'bearer'}),
      );

      final result = await build(adapter).login(email: 'a@b.c', password: 'x');

      expect(result.failureOrNull, const UnknownFailure());
    });
  });

  group('AuthRemoteDataSource.logout', () {
    test('posts_the_refresh_token_to_the_logout_endpoint', () async {
      final adapter = FakeHttpAdapter((_) => const FakeReply(204));

      final result = await build(adapter).logout(refreshToken: 'refresh-123');

      expect(result.isSuccess, isTrue);
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/auth/logout');
      expect(request.data, {'refresh_token': 'refresh-123'});
      expect(request.headers['Authorization'], isNull);
    });

    test('a_failed_logout_is_a_failure_and_does_not_throw', () async {
      final adapter = FakeHttpAdapter((_) => const FakeReply(503, {}));

      final result = await build(adapter).logout(refreshToken: 'refresh-123');

      expect(result.failureOrNull, const ServerUnavailableFailure());
    });
  });
}
