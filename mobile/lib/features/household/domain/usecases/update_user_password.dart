import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/domain/repositories/household_repository.dart';

/// Sets a new password for a person of the house.
class UpdateUserPassword {
  const UpdateUserPassword(this._repository);

  final HouseholdRepository _repository;

  Future<Result<void>> call(String id, String password) =>
      _repository.updatePassword(id, password);
}
