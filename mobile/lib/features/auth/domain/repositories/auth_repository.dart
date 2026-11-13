import 'package:mobile/core/result/result.dart';

/// Opens and closes the session with the API.
abstract interface class AuthRepository {
  /// Checks the credentials and keeps the token. A wrong e-mail or password
  /// comes back as an `UnauthorizedFailure`.
  Future<Result<void>> login({required String email, required String password});

  /// Forgets the token.
  Future<void> logout();
}
