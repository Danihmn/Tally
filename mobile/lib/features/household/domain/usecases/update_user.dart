import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/entities/user_changes.dart';
import 'package:mobile/features/household/domain/repositories/household_repository.dart';

/// Edits the name, nickname and e-mail of a person of the house.
class UpdateUser {
  const UpdateUser(this._repository);

  final HouseholdRepository _repository;

  Future<Result<Member>> call(String id, UserChanges changes) =>
      _repository.updateUser(id, changes);
}
