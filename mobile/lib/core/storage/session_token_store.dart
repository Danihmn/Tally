import 'package:mobile/core/storage/secure_storage.dart';

/// Reads and writes the access token and the refresh token, and nothing else.
///
/// Both live only in [SecureStorage]. They are read on each use and not kept in
/// a field, so they stay in memory only as long as needed.
class SessionTokenStore {
  SessionTokenStore(this._storage);

  static const _accessKey = 'auth_token';
  static const _refreshKey = 'auth_refresh_token';

  final SecureStorage _storage;

  /// The access token (JWT) sent in the `Authorization` header.
  Future<String?> read() => _storage.read(_accessKey);

  /// The refresh token, used to get a new access token when it expires.
  Future<String?> readRefresh() => _storage.read(_refreshKey);

  Future<void> save(String token) => _storage.write(_accessKey, token);

  /// Saves the pair the API sends on login and on refresh.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(_accessKey, accessToken);
    await _storage.write(_refreshKey, refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(_accessKey);
    await _storage.delete(_refreshKey);
  }
}
