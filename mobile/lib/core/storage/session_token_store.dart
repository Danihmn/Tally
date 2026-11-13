import 'package:mobile/core/storage/secure_storage.dart';

/// Reads and writes the JWT, and nothing else.
///
/// The token lives only in [SecureStorage]. It is read on each request and not
/// kept in a field, so it stays in memory only as long as needed.
class SessionTokenStore {
  SessionTokenStore(this._storage);

  static const _key = 'auth_token';

  final SecureStorage _storage;

  Future<String?> read() => _storage.read(_key);

  Future<void> save(String token) => _storage.write(_key, token);

  Future<void> clear() => _storage.delete(_key);
}
