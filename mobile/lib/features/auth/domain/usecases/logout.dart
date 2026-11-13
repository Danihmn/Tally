import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

/// Ends the session on this device.
class Logout {
  const Logout(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.logout();
}
