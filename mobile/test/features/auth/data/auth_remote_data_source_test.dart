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
        }),
      );

      final result = await build(adapter)
          .login(email: 'ana@casa.com', password: 'segredo123');

      expect(result.valueOrNull?.accessToken, 'jwt-123');
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

    test('an_answer_without_a_token_is_an_unknown_failure', () async {
      final adapter = FakeHttpAdapter(
        (_) => const FakeReply(200, {'token_type': 'bearer'}),
      );

      final result = await build(adapter).login(email: 'a@b.c', password: 'x');

      expect(result.failureOrNull, const UnknownFailure());
    });
  });
}
