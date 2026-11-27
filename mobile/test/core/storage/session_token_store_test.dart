import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/storage/session_token_store.dart';

import '../../support/fakes.dart';

void main() {
  group('SessionTokenStore', () {
    test('saves_reads_and_clears_the_token_in_secure_storage', () async {
      final secure = FakeSecureStorage();
      final store = SessionTokenStore(secure);

      expect(await store.read(), isNull);
      await store.save('jwt-123');
      expect(await store.read(), 'jwt-123');
      expect(secure.values.values, contains('jwt-123'));

      await store.clear();
      expect(await store.read(), isNull);
    });

    test('saves_and_reads_the_refresh_token_in_secure_storage', () async {
      final secure = FakeSecureStorage();
      final store = SessionTokenStore(secure);

      expect(await store.readRefresh(), isNull);
      await store.saveTokens(accessToken: 'jwt-1', refreshToken: 'refresh-1');

      expect(await store.read(), 'jwt-1');
      expect(await store.readRefresh(), 'refresh-1');
      expect(secure.values.values, containsAll(['jwt-1', 'refresh-1']));
    });

    test('clear_removes_both_tokens', () async {
      final secure = FakeSecureStorage();
      final store = SessionTokenStore(secure);
      await store.saveTokens(accessToken: 'jwt-1', refreshToken: 'refresh-1');

      await store.clear();

      expect(await store.read(), isNull);
      expect(await store.readRefresh(), isNull);
      expect(secure.values, isEmpty);
    });
  });
}
