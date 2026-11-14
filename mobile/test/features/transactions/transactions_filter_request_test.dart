import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_filters.dart';
import 'package:mobile/features/transactions/domain/transactions_filter_request.dart';

import '../../support/transactions_kit.dart';

void main() {
  group('TransactionsFilterRequest', () {
    test('keeps_the_account_until_it_is_taken', () {
      final request = TransactionsFilterRequest()..requestAccount('a1');

      expect(request.pendingAccountId, 'a1');
      expect(request.take(), 'a1');
      expect(request.pendingAccountId, isNull);
      expect(request.take(), isNull);
      request.dispose();
    });

    test('tells_the_listeners_about_a_new_request', () {
      final request = TransactionsFilterRequest();
      var calls = 0;
      request.addListener(() => calls++);

      request.requestAccount('a1');

      expect(calls, 1);
      request.dispose();
    });
  });

  group('TransactionsViewModel with a requested account', () {
    late TransactionsKit kit;

    tearDown(() => kit.dispose());

    test('a_request_made_before_the_first_load_is_applied_to_it', () async {
      kit = TransactionsKit();
      kit.filterRequest.requestAccount('a2');

      await kit.viewModel.start();

      expect(kit.viewModel.filters, const TransactionFilters(accountId: 'a2'));
      expect(kit.transactions.calls.single.filters.accountId, 'a2');
      expect(kit.filterRequest.pendingAccountId, isNull);
    });

    test(
      'a_request_to_a_list_that_is_alive_reloads_it_by_that_account',
      () async {
        kit = TransactionsKit();
        await kit.viewModel.start();
        kit.viewModel.setSearch('uber');
        kit.transactions.calls.clear();

        kit.filterRequest.requestAccount('a3');
        await pumpEventQueue();

        expect(
          kit.viewModel.filters,
          const TransactionFilters(accountId: 'a3'),
        );
        expect(kit.viewModel.search, '');
        expect(kit.transactions.calls.single.filters.accountId, 'a3');
        expect(kit.transactions.calls.single.search, '');
      },
    );

    test('the_other_filters_are_replaced_and_the_person_stays', () async {
      kit = TransactionsKit();
      await kit.viewModel.start();
      await kit.viewModel.applyFilters(
        const TransactionFilters(accountId: 'a1', minAmount: null),
      );
      kit.transactions.calls.clear();

      kit.filterRequest.requestAccount('a2');
      await pumpEventQueue();

      expect(kit.transactions.calls.single.userId, 'm1');
      expect(kit.viewModel.filters.accountId, 'a2');
    });

    test('without_a_request_nothing_changes', () async {
      kit = TransactionsKit();

      await kit.viewModel.start();

      expect(kit.viewModel.filters.isEmpty, isTrue);
    });
  });
}
