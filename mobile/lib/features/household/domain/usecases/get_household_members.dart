import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/repositories/household_repository.dart';

/// The people of the household of [me], with [me] first and the others by name.
class GetHouseholdMembers {
  const GetHouseholdMembers(this._repository);

  final HouseholdRepository _repository;

  Future<Result<List<Member>>> call(Member me) async {
    final result = await _repository.getUsers();
    return result.map((users) {
      final others =
          users
              .where((u) => u.householdId == me.householdId && u.id != me.id)
              .toList()
            ..sort((a, b) => a.displayName.compareTo(b.displayName));
      return [me, ...others];
    });
  }
}
