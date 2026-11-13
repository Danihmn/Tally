import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/repositories/household_repository.dart';

/// [HouseholdRepository] that answers with what the test sets.
class FakeHouseholdRepository implements HouseholdRepository {
  FakeHouseholdRepository({
    this.me = const Result<Member>.success(
      Member(id: 'me', firstName: 'Ana', householdId: 'house'),
    ),
    this.users = const Result<List<Member>>.success([]),
  });

  Result<Member> me;
  Result<List<Member>> users;

  @override
  Future<Result<Member>> getMe() async => me;

  @override
  Future<Result<List<Member>>> getUsers() async => users;
}
