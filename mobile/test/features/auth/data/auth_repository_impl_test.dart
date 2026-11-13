import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/storage/session_token_store.dart';
import 'package:mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';

import '../../../support/fake_dio.dart';
import '../../../support/fakes.dart';

void main() {
  late FakeSecureStorage storage;

  AuthRepositoryImpl build(FakeReply Function() reply) {
    storage = FakeSecureStorage();
    final tokenStore = SessionTokenStore(storage);
    final dio = buildFakeDio(
      FakeHttpAdapter((_) => reply()),
      tokenStore: tokenStore,
    );
    return AuthRepositoryImpl(
      remote: AuthRemoteDataSource(dio),
      tokenStore: tokenStore,
    );
  }

  group('AuthRepositoryImpl', () {
    test('a_successful_login_keeps_the_token', () async {
      final repository = build(
        () => const FakeReply(200, {
          'access_token': 'jwt-123',
          'token_type': 'bearer',
        }),
      );

      final result = await repository.login(email: 'a@b.c', password: 'x');

      expect(result.isSuccess, isTrue);
      expect(storage.values['auth_token'], 'jwt-123');
    });

    test('a_failed_login_keeps_no_token', () async {
      final repository = build(() => const FakeReply(401, {}));

      final result = await repository.login(email: 'a@b.c', password: 'x');

      expect(result.failureOrNull, const UnauthorizedFailure());
      expect(storage.values, isEmpty);
    });

    test('logout_forgets_the_token', () async {
      final repository = build(() => const FakeReply(200, {}));
      storage.values['auth_token'] = 'jwt-123';

      await repository.logout();

      expect(storage.values, isEmpty);
    });
  });
}
