import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/entities/user_draft.dart';
import 'package:mobile/features/household/domain/repositories/household_repository.dart';

/// Adds a person to the house of the logged user.
class CreateUser {
  const CreateUser(this._repository);

  final HouseholdRepository _repository;

  Future<Result<Member>> call(UserDraft draft) => _repository.createUser(draft);
}
