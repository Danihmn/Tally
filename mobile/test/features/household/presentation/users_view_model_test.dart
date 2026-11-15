import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/entities/pluggy_credentials.dart';
import 'package:mobile/features/household/domain/entities/user_changes.dart';
import 'package:mobile/features/household/domain/entities/user_draft.dart';

import '../../../support/users_kit.dart';

void main() {
  late UsersKit kit;

  setUp(() => kit = UsersKit());
  tearDown(() async {
    kit.viewModel.dispose();
    await kit.dispose();
  });

  const draft = UserDraft(
    firstName: 'Carla',
    email: 'carla@casa.com',
    password: 'segredo123',
    pluggyClientId: '11111111-2222-3333-4444-555555555555',
    pluggyClientSecret: 's3cr3t',
  );
  const carla = Member(
    id: 'm3',
    firstName: 'Carla',
    email: 'carla@casa.com',
    householdId: 'h1',
  );

  group('UsersViewModel', () {
    test('loads_the_people_of_the_house_with_the_logged_one_first', () async {
      await kit.viewModel.load();

      expect(kit.viewModel.members, [aninha, bia]);
      expect(kit.viewModel.me, aninha);
      expect(kit.viewModel.memberById('m2'), bia);
      expect(kit.viewModel.memberById('zzz'), isNull);
    });

    test('creating_a_person_reloads_the_list_in_place', () async {
      await kit.viewModel.load();
      kit.household.users = const Result.success([aninha, bia, carla]);
      var loadingSeen = false;
      kit.viewModel.addListener(() {
        if (kit.viewModel.members.isEmpty) loadingSeen = true;
      });

      final result = await kit.viewModel.create(draft);

      expect(result.isSuccess, isTrue);
      expect(kit.household.created.single, draft);
      expect(kit.viewModel.members, [aninha, bia, carla]);
      expect(loadingSeen, isFalse);
    });

    test('a_failed_creation_keeps_the_list_and_returns_the_failure', () async {
      await kit.viewModel.load();
      kit.household.createResult = const Result.failure(
        EmailAlreadyExistsFailure(),
      );
      final usersCalls = kit.household.usersCalls;

      final result = await kit.viewModel.create(draft);

      expect(result.failureOrNull, const EmailAlreadyExistsFailure());
      expect(kit.household.usersCalls, usersCalls);
      expect(kit.viewModel.members, [aninha, bia]);
    });

    test('editing_a_person_shows_the_new_data', () async {
      await kit.viewModel.load();
      const renamed = Member(
        id: 'm2',
        firstName: 'Bia',
        surname: 'Bibi',
        householdId: 'h1',
      );
      kit.household.users = const Result.success([aninha, renamed]);

      final result = await kit.viewModel.update(
        'm2',
        const UserChanges(
          firstName: 'Bia',
          surname: 'Bibi',
          email: 'bia@casa.com',
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(kit.household.updated.single.$1, 'm2');
      expect(kit.viewModel.memberById('m2')?.displayName, 'Bibi');
    });

    test('a_failed_edit_returns_the_failure', () async {
      await kit.viewModel.load();
      kit.household.updateResult = const Result.failure(NotFoundFailure());

      final result = await kit.viewModel.update(
        'm2',
        const UserChanges(firstName: 'Bia', email: 'bia@casa.com'),
      );

      expect(result.failureOrNull, const NotFoundFailure());
    });

    test('changing_the_credentials_does_not_reload_the_list', () async {
      await kit.viewModel.load();
      final usersCalls = kit.household.usersCalls;
      const credentials = PluggyCredentials(clientId: 'id', clientSecret: 's');

      final result = await kit.viewModel.updateCredentials('m2', credentials);

      expect(result.isSuccess, isTrue);
      expect(kit.household.credentialsSent.single, ('m2', credentials));
      expect(kit.household.usersCalls, usersCalls);
    });

    test('listeners_hear_about_changes_of_the_shared_list', () async {
      var heard = 0;
      kit.viewModel.addListener(() => heard++);

      await kit.viewModel.load();

      expect(heard, greaterThan(0));
    });
  });
}
