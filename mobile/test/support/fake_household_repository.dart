import 'dart:async';

import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/repositories/household_repository.dart';

/// [HouseholdRepository] that answers with what the test sets and counts the
/// calls. Set [meGate] to hold the answer of `getMe`.
class FakeHouseholdRepository implements HouseholdRepository {
  FakeHouseholdRepository({
    this.me = const Result<Member>.success(
      Member(id: 'me', firstName: 'Ana', householdId: 'house'),
    ),
    this.users = const Result<List<Member>>.success([]),
  });

  Result<Member> me;
  Result<List<Member>> users;
  Completer<Result<Member>>? meGate;
  int meCalls = 0;
  int usersCalls = 0;

  @override
  Future<Result<Member>> getMe() {
    meCalls++;
    final gate = meGate;
    if (gate != null) return gate.future;
    return Future.value(me);
  }

  @override
  Future<Result<List<Member>>> getUsers() async {
    usersCalls++;
    return users;
  }
}
