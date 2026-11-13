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
  });
}
