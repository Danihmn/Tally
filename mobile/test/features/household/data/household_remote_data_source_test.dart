import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/features/household/data/datasources/household_remote_data_source.dart';
import 'package:mobile/features/household/data/models/member_dto.dart';
import 'package:mobile/features/household/data/repositories/household_repository_impl.dart';
import 'package:mobile/features/household/domain/entities/member.dart';

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
        const Member(id: 'm1', firstName: 'Ana', householdId: 'h1'),
      );
    });
  });
}
