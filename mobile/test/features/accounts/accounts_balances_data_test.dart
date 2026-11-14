import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/features/accounts/data/datasources/accounts_remote_data_source.dart';
import 'package:mobile/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:mobile/features/accounts/domain/entities/account_balance.dart';
import 'package:mobile/features/accounts/domain/usecases/get_account_balances.dart';
import 'package:mobile/features/accounts/domain/usecases/get_total_balance.dart';

import '../../support/fake_dio.dart';
import '../../support/fakes.dart';

Map<String, dynamic> item(String id, String type) => {
  'id': id,
  'user_id': 'm1',
  'type': type,
  'subtype': 'X',
  'name': 'Conta',
  'marketing_name': null,
  'number': '1234',
  'currency_code': 'BRL',
  'balance': '10.00',
  'updated_at': null,
  'credit': null,
};

void main() {
  AccountsRemoteDataSource build(FakeHttpAdapter adapter) =>
      AccountsRemoteDataSource(buildFakeDio(adapter));

  FakeHttpAdapter answering(Object? body, {int status = 200}) =>
      FakeHttpAdapter((_) => FakeReply(status, body));

  group('AccountsRemoteDataSource.getBalances', () {
    test('asks_for_the_balances_without_a_person_for_the_house', () async {
      final adapter = answering([item('a', 'BANK'), item('b', 'CREDIT')]);

      final result = await build(adapter).getBalances();

      expect(result.valueOrNull, hasLength(2));
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/bank-accounts/balances');
      expect(request.queryParameters, isEmpty);
    });

    test('the_person_is_sent_as_user_id', () async {
      final adapter = answering(<Object?>[]);

      await build(adapter).getBalances(userId: 'm2');

      expect(adapter.requests.single.queryParameters, {'user_id': 'm2'});
    });

    test('a_401_is_unauthorized_and_a_503_is_unavailable', () async {
      final denied = await build(answering({}, status: 401)).getBalances();
      final down = await build(answering({}, status: 503)).getBalances();

      expect(denied.failureOrNull, const UnauthorizedFailure());
      expect(down.failureOrNull, const ServerUnavailableFailure());
    });

    test('an_item_without_a_required_field_is_an_unknown_failure', () async {
      final result = await build(
        answering([
          {'id': 'a'},
        ]),
      ).getBalances();

      expect(result.failureOrNull, const UnknownFailure());
    });
  });

  group('AccountsRemoteDataSource.getTotalBalance', () {
    test('asks_for_the_total_of_one_kind', () async {
      final adapter = answering({'type': 'BANK', 'total': '3500.75'});

      final result = await build(adapter)
          .getTotalBalance(kind: AccountKind.bank);

      expect(result.valueOrNull, Decimal.parse('3500.75'));
      final request = adapter.requests.single;
      expect(request.path, '/bank-accounts/total-balance');
      expect(request.queryParameters, {'type': 'BANK'});
    });

    test('the_kind_and_the_person_are_sent', () async {
      final adapter = answering({'type': 'CREDIT', 'total': '0'});

      await build(adapter)
          .getTotalBalance(kind: AccountKind.credit, userId: 'm1');

      expect(adapter.requests.single.queryParameters, {
        'type': 'CREDIT',
        'user_id': 'm1',
      });
    });

    test('a_total_that_is_not_a_number_is_an_unknown_failure', () async {
      final result = await build(answering({'total': 'abc'}))
          .getTotalBalance(kind: AccountKind.bank);

      expect(result.failureOrNull, const UnknownFailure());
    });
  });

  group('repository and use cases', () {
    AccountsRepositoryImpl repository(FakeHttpAdapter adapter) =>
        AccountsRepositoryImpl(build(adapter));

    test('the_balances_become_entities', () async {
      final adapter = answering([item('a', 'BANK'), item('b', 'CREDIT')]);

      final result = await GetAccountBalances(repository(adapter))();

      final accounts = result.valueOrNull!;
      expect(accounts.map((a) => a.id), ['a', 'b']);
      expect(accounts.last.isCreditCard, isTrue);
    });

    test('the_total_goes_through_as_a_decimal', () async {
      final adapter = answering({'type': 'BANK', 'total': '12.30'});

      final result = await GetTotalBalance(repository(adapter))(
        kind: AccountKind.bank,
        userId: 'm1',
      );

      expect(result.valueOrNull, Decimal.parse('12.30'));
      expect(adapter.requests.single.queryParameters['user_id'], 'm1');
    });
  });
}
