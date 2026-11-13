import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

/// Logs in with e-mail and password.
class Login {
  const Login(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call({
    required String email,
    required String password,
  }) => _repository.login(email: email, password: password);
}
