import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/usecases/get_household_members.dart';

import '../../../support/fake_household_repository.dart';

void main() {
  const me = Member(id: 'm1', firstName: 'Ana', householdId: 'h1');
  const bia = Member(id: 'm2', firstName: 'Bia', householdId: 'h1');
  const caio = Member(id: 'm3', firstName: 'Caio', householdId: 'h1');
  const stranger = Member(id: 'm9', firstName: 'Zé', householdId: 'h2');

  Future<Result<List<Member>>> run(List<Member> users) {
    final repository = FakeHouseholdRepository(
      users: Result<List<Member>>.success(users),
    );
    return GetHouseholdMembers(repository)(me);
  }

  group('GetHouseholdMembers', () {
    test('keeps_only_the_people_of_the_same_household', () async {
      final result = await run([me, bia, stranger]);

      expect(result.valueOrNull, [me, bia]);
    });

    test('puts_the_logged_user_first_and_the_others_by_name', () async {
      final result = await run([caio, bia, me]);

      expect(result.valueOrNull, [me, bia, caio]);
    });

    test('the_others_are_sorted_by_the_nickname_when_they_have_one', () async {
      const dudu = Member(
        id: 'm4',
        firstName: 'Eduardo',
        surname: 'Aaron',
        householdId: 'h1',
      );

      final result = await run([caio, dudu, bia, me]);

      expect(result.valueOrNull, [me, dudu, bia, caio]);
    });

    test('the_logged_user_is_there_even_if_the_list_leaves_them_out', () async {
      final result = await run([bia]);

      expect(result.valueOrNull, [me, bia]);
    });

    test('a_failure_goes_through_unchanged', () async {
      final repository = FakeHouseholdRepository(
        users: const Result<List<Member>>.failure(NetworkFailure()),
      );

      final result = await GetHouseholdMembers(repository)(me);

      expect(result.failureOrNull, const NetworkFailure());
    });
  });
}
