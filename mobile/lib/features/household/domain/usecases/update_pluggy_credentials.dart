import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/domain/entities/pluggy_credentials.dart';
import 'package:mobile/features/household/domain/repositories/household_repository.dart';

/// Replaces the Pluggy credentials of a person of the house.
class UpdatePluggyCredentials {
  const UpdatePluggyCredentials(this._repository);

  final HouseholdRepository _repository;

  Future<Result<void>> call(String id, PluggyCredentials credentials) =>
      _repository.updatePluggyCredentials(id, credentials);
}
