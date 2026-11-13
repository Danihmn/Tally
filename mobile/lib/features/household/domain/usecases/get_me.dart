import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/repositories/household_repository.dart';

/// Loads the logged user.
class GetMe {
  const GetMe(this._repository);

  final HouseholdRepository _repository;

  Future<Result<Member>> call() => _repository.getMe();
}
