import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/features/accounts/data/datasources/accounts_remote_data_source.dart';
import 'package:mobile/features/accounts/data/mappers/bank_account_mapper.dart';
import 'package:mobile/features/accounts/data/models/bank_account_dto.dart';
import 'package:mobile/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';

import '../../support/fake_dio.dart';
import '../../support/fakes.dart';

const _nubank = {
  'id': 'a1',
  'user_id': 'm1',
  'pluggy_item_id': 'item',
  'type': 'BANK',
  'subtype': 'CHECKING_ACCOUNT',
  'name': 'Conta Corrente',
  'marketing_name': 'Nubank',
  'number': '0001/12345-6',
  'currency_code': 'BRL',
  'owner': 'ANA',
  'balance': '2301.45',
};

void main() {
  group('BankAccount', () {
    BankAccount build({String? marketing, String number = '0001/12345-6'}) =>
        BankAccount(
          id: 'a1',
          ownerId: 'm1',
          name: 'Conta Corrente',
          marketingName: marketing,
          number: number,
          isCreditCard: false,
        );

    test('the_display_name_is_the_marketing_name_when_there_is_one', () {
      expect(build(marketing: 'Nubank').displayName, 'Nubank');
    });

    test('without_a_marketing_name_it_is_the_account_name', () {
      expect(build().displayName, 'Conta Corrente');
      expect(build(marketing: '  ').displayName, 'Conta Corrente');
    });

    test('the_short_number_is_the_last_four_digits', () {
      expect(build().shortNumber, '3456');
      expect(build(number: '1234').shortNumber, '1234');
      expect(build(number: '12').shortNumber, '12');
      expect(build(number: 'no digits').shortNumber, 'no digits');
    });
  });

  group('BankAccountDto', () {
    test('reads_the_fields_the_app_uses', () {
      final account = BankAccountDto.fromJson(_nubank).toEntity();

      expect(account.id, 'a1');
      expect(account.ownerId, 'm1');
      expect(account.displayName, 'Nubank');
      expect(account.isCreditCard, isFalse);
    });

    test('a_credit_card_is_known_by_the_type', () {
      final dto = BankAccountDto.fromJson({..._nubank, 'type': 'CREDIT'});

      expect(dto.toEntity().isCreditCard, isTrue);
    });

    test('the_marketing_name_and_the_number_may_be_missing', () {
      final dto = BankAccountDto.fromJson({
        'id': 'a1',
        'user_id': 'm1',
        'type': 'BANK',
        'name': 'Conta',
        'marketing_name': null,
      });

      expect(dto.marketingName, isNull);
      expect(dto.number, '');
    });

    test('a_missing_required_field_is_a_format_error', () {
      expect(
        () => BankAccountDto.fromJson({'id': 'a1', 'name': 'Conta'}),
        throwsFormatException,
      );
    });
  });

  group('AccountsRemoteDataSource', () {
    test('lists_the_accounts_asking_for_the_biggest_page', () async {
      final adapter = FakeHttpAdapter((_) => const FakeReply(200, [_nubank]));

      final result = await AccountsRemoteDataSource(buildFakeDio(adapter))
          .getAccounts();

      expect(result.valueOrNull?.single.name, 'Conta Corrente');
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/bank-accounts');
      expect(request.queryParameters, {'limit': 100});
    });

    test('an_empty_list_is_fine', () async {
      final adapter = FakeHttpAdapter((_) => const FakeReply(200, <Object?>[]));

      final result = await AccountsRemoteDataSource(buildFakeDio(adapter))
          .getAccounts();

      expect(result.valueOrNull, isEmpty);
    });

    test('an_unexpected_item_is_an_unknown_failure', () async {
      final adapter = FakeHttpAdapter((_) => const FakeReply(200, [1]));

      final result = await AccountsRemoteDataSource(buildFakeDio(adapter))
          .getAccounts();

      expect(result.failureOrNull, const UnknownFailure());
    });

    test('a_401_is_an_unauthorized_failure', () async {
      final adapter = FakeHttpAdapter((_) => const FakeReply(401, {}));

      final result = await AccountsRemoteDataSource(buildFakeDio(adapter))
          .getAccounts();

      expect(result.failureOrNull, const UnauthorizedFailure());
    });
  });

  test('the_repository_turns_the_dtos_into_entities', () async {
    final adapter = FakeHttpAdapter((_) => const FakeReply(200, [_nubank]));
    final repository = AccountsRepositoryImpl(
      AccountsRemoteDataSource(buildFakeDio(adapter)),
    );

    final result = await repository.getAccounts();

    expect(result.valueOrNull?.single.displayName, 'Nubank');
  });
}
