import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/features/household/data/datasources/household_remote_data_source.dart';
import 'package:mobile/features/household/data/models/member_dto.dart';
import 'package:mobile/features/household/data/repositories/household_repository_impl.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/entities/pluggy_credentials.dart';
import 'package:mobile/features/household/domain/entities/user_changes.dart';
import 'package:mobile/features/household/domain/entities/user_draft.dart';

import '../../../support/fake_dio.dart';
import '../../../support/fakes.dart';

const _ana = {
  'id': 'm1',
  'first_name': 'Ana',
  'email': 'ana@casa.com',
  'household_id': 'h1',
  'created_at': '2026-01-01T10:00:00Z',
};

void main() {
  HouseholdRemoteDataSource build(FakeHttpAdapter adapter) =>
      HouseholdRemoteDataSource(buildFakeDio(adapter));

  group('MemberDto.fromJson', () {
    test('reads_the_fields_the_app_uses', () {
      final dto = MemberDto.fromJson(_ana);

      expect((dto.id, dto.firstName, dto.householdId), ('m1', 'Ana', 'h1'));
    });

    test('reads_the_last_name_the_nickname_and_the_email', () {
      final dto = MemberDto.fromJson({
        ..._ana,
        'last_name': 'Souza',
        'surname': 'Aninha',
      });

      expect(
        (dto.lastName, dto.surname, dto.email),
        ('Souza', 'Aninha', 'ana@casa.com'),
      );
    });

    test('a_user_without_last_name_and_nickname_is_still_valid', () {
      final dto = MemberDto.fromJson({..._ana, 'last_name': null});

      expect((dto.lastName, dto.surname), (null, null));
    });

    test('a_missing_field_is_a_format_error', () {
      expect(
        () => MemberDto.fromJson({'id': 'm1', 'first_name': 'Ana'}),
        throwsFormatException,
      );
    });
  });

  group('HouseholdRemoteDataSource', () {
    test('gets_the_logged_user_from_users_me', () async {
      final adapter = FakeHttpAdapter((_) => const FakeReply(200, _ana));

      final result = await build(adapter).getMe();

      expect(result.valueOrNull?.firstName, 'Ana');
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/users/me');
    });

    test('lists_the_users_asking_for_the_biggest_page', () async {
      final adapter = FakeHttpAdapter(
        (_) => const FakeReply(200, [
          _ana,
          {
            'id': 'm2',
            'first_name': 'Bia',
            'email': 'bia@casa.com',
            'household_id': 'h1',
            'created_at': '2026-01-02T10:00:00Z',
          },
        ]),
      );

      final result = await build(adapter).getUsers();

      expect(result.valueOrNull?.map((u) => u.firstName), ['Ana', 'Bia']);
      expect(adapter.requests.single.path, '/users');
      expect(adapter.requests.single.queryParameters, {'limit': 100});
    });

    test('an_unexpected_item_is_an_unknown_failure', () async {
      final adapter = FakeHttpAdapter((_) => const FakeReply(200, [123]));

      final result = await build(adapter).getUsers();

      expect(result.failureOrNull, const UnknownFailure());
    });

    test('a_401_is_an_unauthorized_failure', () async {
      final adapter = FakeHttpAdapter((_) => const FakeReply(401, {}));

      final result = await build(adapter).getMe();

      expect(result.failureOrNull, const UnauthorizedFailure());
    });
  });

  group('HouseholdRepositoryImpl', () {
    test('turns_the_dtos_into_entities', () async {
      final adapter = FakeHttpAdapter((_) => const FakeReply(200, _ana));
      final repository = HouseholdRepositoryImpl(build(adapter));

      final result = await repository.getMe();

      expect(
        result.valueOrNull,
        const Member(
          id: 'm1',
          firstName: 'Ana',
          householdId: 'h1',
          email: 'ana@casa.com',
        ),
      );
    });
  });

  group('HouseholdRemoteDataSource writes', () {
    const draft = UserDraft(
      firstName: ' Carla ',
      surname: 'Cacá',
      email: ' carla@casa.com ',
      password: 'segredo123',
      pluggyClientId: '11111111-2222-3333-4444-555555555555',
      pluggyClientSecret: ' s3cr3t ',
    );

    test('creating_a_user_posts_the_form_without_a_household', () async {
      final adapter = FakeHttpAdapter(
        (_) => const FakeReply(201, {..._ana, 'surname': 'Cacá'}),
      );

      final result = await build(adapter).createUser(draft);

      final request = adapter.requests.single;
      expect((request.method, request.path), ('POST', '/users'));
      expect(request.data, {
        'first_name': 'Carla',
        'last_name': null,
        'surname': 'Cacá',
        'email': 'carla@casa.com',
        'password': 'segredo123',
        'pluggy_client_id': '11111111-2222-3333-4444-555555555555',
        'pluggy_client_secret': 's3cr3t',
      });
      expect((request.data as Map).containsKey('household_id'), isFalse);
      expect(result.valueOrNull?.surname, 'Cacá');
    });

    test('an_email_that_is_taken_is_its_own_failure', () async {
      final adapter = FakeHttpAdapter(
        (_) => const FakeReply(409, {
          'detail': 'Record already exists',
          'code': 'EMAIL_ALREADY_EXISTS',
        }),
      );

      final result = await build(adapter).createUser(draft);

      expect(result.failureOrNull, const EmailAlreadyExistsFailure());
    });

    test('any_other_conflict_stays_a_conflict', () async {
      final adapter = FakeHttpAdapter(
        (_) => const FakeReply(409, {'detail': 'Record already exists'}),
      );

      final result = await build(adapter).createUser(draft);

      expect(result.failureOrNull, const ConflictFailure());
    });

    test(
      'editing_a_user_patches_the_four_fields_and_clears_the_blanks',
      () async {
        final adapter = FakeHttpAdapter((_) => const FakeReply(200, _ana));

        await build(adapter).updateUser(
          'm1',
          const UserChanges(firstName: 'Ana', email: 'ana@casa.com'),
        );

        final request = adapter.requests.single;
        expect((request.method, request.path), ('PATCH', '/users/m1'));
        expect(request.data, {
          'first_name': 'Ana',
          'last_name': null,
          'surname': null,
          'email': 'ana@casa.com',
        });
      },
    );

    test('changing_the_credentials_puts_both_values', () async {
      final adapter = FakeHttpAdapter((_) => const FakeReply(204));

      final result = await build(adapter).updatePluggyCredentials(
        'm1',
        const PluggyCredentials(clientId: ' id ', clientSecret: ' secret '),
      );

      final request = adapter.requests.single;
      expect(
        (request.method, request.path),
        ('PUT', '/users/m1/pluggy-credentials'),
      );
      expect(request.data, {
        'pluggy_client_id': 'id',
        'pluggy_client_secret': 'secret',
      });
      expect(result.isSuccess, isTrue);
    });

    test('changing_the_password_puts_it_as_typed', () async {
      final adapter = FakeHttpAdapter((_) => const FakeReply(204));

      final result = await build(adapter).updatePassword('m1', ' new pass ');

      final request = adapter.requests.single;
      expect((request.method, request.path), ('PUT', '/users/m1/password'));
      expect(request.data, {'password': ' new pass '});
      expect(result.isSuccess, isTrue);
    });
  });
}
