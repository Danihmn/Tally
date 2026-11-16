import 'dart:async';

import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/entities/pluggy_credentials.dart';
import 'package:mobile/features/household/domain/entities/user_changes.dart';
import 'package:mobile/features/household/domain/entities/user_draft.dart';
import 'package:mobile/features/household/domain/repositories/household_repository.dart';

/// [HouseholdRepository] that answers with what the test sets and counts the
/// calls. Set [meGate] to hold the answer of `getMe`.
class FakeHouseholdRepository implements HouseholdRepository {
  FakeHouseholdRepository({
    this.me = const Result<Member>.success(
      Member(id: 'me', firstName: 'Ana', householdId: 'house'),
    ),
    this.users = const Result<List<Member>>.success([]),
    this.createResult,
    this.updateResult,
    this.credentialsResult = const Result<void>.success(null),
    this.passwordResult = const Result<void>.success(null),
  });

  Result<Member> me;
  Result<List<Member>> users;
  Completer<Result<Member>>? meGate;
  int meCalls = 0;
  int usersCalls = 0;

  /// What `createUser` and `updateUser` answer. When `null`, the person built
  /// from what was sent.
  Result<Member>? createResult;
  Result<Member>? updateResult;
  Result<void> credentialsResult;
  Result<void> passwordResult;
  final List<UserDraft> created = [];
  final List<(String, UserChanges)> updated = [];
  final List<(String, PluggyCredentials)> credentialsSent = [];
  final List<(String, String)> passwordsSent = [];

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

  @override
  Future<Result<Member>> createUser(UserDraft draft) async {
    created.add(draft);
    return createResult ??
        Result.success(
          Member(
            id: 'new',
            firstName: draft.firstName,
            lastName: draft.lastName,
            surname: draft.surname,
            email: draft.email,
            householdId: 'house',
          ),
        );
  }

  @override
  Future<Result<Member>> updateUser(String id, UserChanges changes) async {
    updated.add((id, changes));
    return updateResult ??
        Result.success(
          Member(
            id: id,
            firstName: changes.firstName,
            lastName: changes.lastName,
            surname: changes.surname,
            email: changes.email,
            householdId: 'house',
          ),
        );
  }

  @override
  Future<Result<void>> updatePluggyCredentials(
    String id,
    PluggyCredentials credentials,
  ) async {
    credentialsSent.add((id, credentials));
    return credentialsResult;
  }

  @override
  Future<Result<void>> updatePassword(String id, String password) async {
    passwordsSent.add((id, password));
    return passwordResult;
  }
}
