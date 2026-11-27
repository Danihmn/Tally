import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/storage/session_token_store.dart';
import 'package:mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';

import '../../../support/fake_dio.dart';
import '../../../support/fakes.dart';

void main() {
  late FakeSecureStorage storage;
  late FakeHttpAdapter adapter;

  AuthRepositoryImpl build(FakeReply Function() reply) {
    storage = FakeSecureStorage();
    final tokenStore = SessionTokenStore(storage);
    adapter = FakeHttpAdapter((_) => reply());
    final dio = buildFakeDio(
      adapter,
      tokenStore: tokenStore,
    );
    return AuthRepositoryImpl(
      remote: AuthRemoteDataSource(dio),
      tokenStore: tokenStore,
    );
  }

  group('AuthRepositoryImpl', () {
    test('a_successful_login_keeps_both_tokens', () async {
      final repository = build(
        () => const FakeReply(200, {
          'access_token': 'jwt-123',
          'token_type': 'bearer',
          'refresh_token': 'refresh-123',
        }),
      );

      final result = await repository.login(email: 'a@b.c', password: 'x');

      expect(result.isSuccess, isTrue);
      expect(storage.values['auth_token'], 'jwt-123');
      expect(storage.values['auth_refresh_token'], 'refresh-123');
    });

    test('a_failed_login_keeps_no_token', () async {
      final repository = build(() => const FakeReply(401, {}));

      final result = await repository.login(email: 'a@b.c', password: 'x');

      expect(result.failureOrNull, const UnauthorizedFailure());
      expect(storage.values, isEmpty);
    });

    test('logout_forgets_both_tokens', () async {
      final repository = build(() => const FakeReply(204));
      storage.values['auth_token'] = 'jwt-123';
      storage.values['auth_refresh_token'] = 'refresh-123';

      await repository.logout();

      expect(storage.values, isEmpty);
    });

    test('logout_asks_the_api_to_revoke_the_refresh_token', () async {
      final repository = build(() => const FakeReply(204));
      storage.values['auth_refresh_token'] = 'refresh-123';

      await repository.logout();
      await pumpEventQueue();

      final request = adapter.requests.single;
      expect(request.path, '/auth/logout');
      expect(request.data, {'refresh_token': 'refresh-123'});
    });

    test('logout_works_even_when_the_api_is_down', () async {
      final repository = build(() => const FakeReply(503, {}));
      storage.values['auth_token'] = 'jwt-123';
      storage.values['auth_refresh_token'] = 'refresh-123';

      await repository.logout();
      await pumpEventQueue();

      expect(storage.values, isEmpty);
    });

    test('logout_without_a_refresh_token_calls_no_endpoint', () async {
      final repository = build(() => const FakeReply(204));
      storage.values['auth_token'] = 'jwt-123';

      await repository.logout();
      await pumpEventQueue();

      expect(adapter.requests, isEmpty);
    });
  });
}
