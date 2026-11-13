import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/pagination/page_result.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/features/accounts/domain/entities/bank_account.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';
import 'package:mobile/features/transactions/domain/entities/transaction_filters.dart';

import '../../../support/transaction_factory.dart';
import '../../../support/transactions_kit.dart';

void main() {
  late TransactionsKit kit;

  Future<TransactionsKit> started() async {
    kit = TransactionsKit();
    await kit.viewModel.start();
    return kit;
  }

  tearDown(() => kit.dispose());

  group('start', () {
    test('loads_the_first_page_for_me', () async {
      await started();

      final call = kit.transactions.calls.single;
      expect((call.offset, call.limit), (0, 30));
      expect(call.userId, 'm1');
      expect(call.filters.isEmpty, isTrue);
      expect(call.search, '');
      expect(kit.viewModel.items, hasLength(30));
      expect(kit.viewModel.total, 75);
    });

    test('loads_the_accounts_beside_the_list', () async {
      await started();

      expect(kit.accounts.calls, 1);
      expect(kit.viewModel.accountList, hasLength(3));
      expect(kit.viewModel.accountOf('a1')?.displayName, 'Nubank');
      expect(kit.viewModel.accountOf('nope'), isNull);
    });

    test('a_failed_profile_is_the_state_and_makes_no_request', () async {
      kit = TransactionsKit();
      kit.household.me = const Result.failure(NetworkFailure());

      await kit.viewModel.start();

      expect(kit.viewModel.profile, isA<UiError<HouseholdProfile>>());
      expect(kit.transactions.calls, isEmpty);
      expect(kit.accounts.calls, 0);
    });

    test('a_failed_first_page_is_the_state_of_the_list', () async {
      kit = TransactionsKit();
      kit.transactions.forced = const Result.failure(
        ServerUnavailableFailure(),
      );

      await kit.viewModel.start();

      expect(kit.viewModel.state, isA<UiError<List<Transaction>>>());
    });

    test('an_empty_first_page_is_the_empty_state', () async {
      kit = TransactionsKit();
      kit.transactions.all = [];

      await kit.viewModel.start();

      expect(kit.viewModel.state, isA<UiEmpty<List<Transaction>>>());
    });

    test('the_days_are_grouped_newest_first', () async {
      await started();

      final groups = kit.viewModel.groups;

      expect(groups.first.day, DateTime(2026, 11, 12));
      expect(groups.first.items, hasLength(6));
      expect(groups, hasLength(5));
    });

    test('today_comes_from_the_clock', () async {
      await started();

      expect(kit.viewModel.today, DateTime(2026, 11, 13));
    });
  });

  group('paging', () {
    test('load_more_asks_for_the_next_page', () async {
      await started();

      await kit.viewModel.loadMore();

      expect(kit.transactions.calls.last.offset, 30);
      expect(kit.viewModel.items, hasLength(60));
      expect(kit.viewModel.hasMore, isTrue);
    });

    test('the_last_page_ends_the_list', () async {
      await started();
      await kit.viewModel.loadMore();
      await kit.viewModel.loadMore();

      expect(kit.viewModel.items, hasLength(75));
      expect(kit.viewModel.hasMore, isFalse);
    });

    test('the_filters_and_the_person_stay_when_paging', () async {
      await started();
      await kit.viewModel.applyFilters(
        const TransactionFilters(accountId: 'a1'),
      );

      await kit.viewModel.loadMore();

      final call = kit.transactions.calls.last;
      expect(call.offset, 30);
      expect(call.filters.accountId, 'a1');
      expect(call.userId, 'm1');
    });
  });

  group('who appears', () {
    test('the_house_asks_without_a_person_and_keeps_the_filters', () async {
      await started();
      await kit.viewModel.applyFilters(
        const TransactionFilters(accountId: 'a1'),
      );

      await kit.viewModel.selectScope(const ScopeOption.house());

      final call = kit.transactions.calls.last;
      expect(call.userId, isNull);
      expect(call.offset, 0);
      expect(call.filters.accountId, 'a1');
    });

    test('another_person_asks_for_that_person', () async {
      await started();

      await kit.viewModel.selectScope(const ScopeOption.person(bia));

      expect(kit.transactions.calls.last.userId, 'm2');
    });

    test('a_choice_made_on_another_screen_reloads_the_list', () async {
      await started();
      kit.transactions.calls.clear();

      kit.scope.select(const ScopeOption.house());
      await pumpEventQueue();

      expect(kit.transactions.calls.single.userId, isNull);
    });

    test('choosing_the_same_option_again_does_nothing', () async {
      await started();
      kit.transactions.calls.clear();

      await kit.viewModel.selectScope(ScopeOption.me(ana));

      expect(kit.transactions.calls, isEmpty);
    });
  });

  group('search', () {
    test('waits_for_a_pause_before_asking', () {
      fakeAsync((async) {
        kit = TransactionsKit();
        unawaited(kit.viewModel.start());
        async.flushMicrotasks();
        kit.transactions.calls.clear();

        kit.viewModel.setSearch('compra 1');
        async.elapse(const Duration(milliseconds: 200));
        expect(kit.transactions.calls, isEmpty);
        async.elapse(const Duration(milliseconds: 150));
        async.flushMicrotasks();

        expect(kit.transactions.calls.single.search, 'compra 1');
        expect(kit.transactions.calls.single.offset, 0);
      });
    });

    test('typing_again_before_the_pause_makes_one_request', () {
      fakeAsync((async) {
        kit = TransactionsKit();
        unawaited(kit.viewModel.start());
        async.flushMicrotasks();
        kit.transactions.calls.clear();

        kit.viewModel.setSearch('c');
        async.elapse(const Duration(milliseconds: 100));
        kit.viewModel.setSearch('co');
        async.elapse(const Duration(milliseconds: 100));
        kit.viewModel.setSearch('com');
        async.elapse(const Duration(milliseconds: 400));
        async.flushMicrotasks();

        expect(kit.transactions.calls, hasLength(1));
        expect(kit.transactions.calls.single.search, 'com');
      });
    });

    test('the_text_is_known_at_once_even_before_the_list_reacts', () {
      fakeAsync((async) {
        kit = TransactionsKit();
        unawaited(kit.viewModel.start());
        async.flushMicrotasks();

        kit.viewModel.setSearch('uber');

        expect(kit.viewModel.search, 'uber');
        expect(kit.viewModel.hasSearchOrFilters, isTrue);
      });
    });

    test('clearing_the_search_reloads_at_once', () async {
      await started();
      kit.viewModel.setSearch('uber');
      kit.transactions.calls.clear();

      kit.viewModel.clearSearch();
      await pumpEventQueue();

      expect(kit.transactions.calls.single.search, '');
      expect(kit.viewModel.search, '');
    });

    test('the_result_is_what_matches_and_its_total', () async {
      await started();
      kit.viewModel.setSearch('Compra 7');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await pumpEventQueue();

      // Compra 7, 70, 71, 72, 73, 74
      expect(kit.viewModel.total, 6);
    });
  });

  group('filters', () {
    test('applying_reloads_from_the_start_with_the_filters', () async {
      await started();
      await kit.viewModel.loadMore();
      final filters = TransactionFilters(
        direction: TransactionDirection.credit,
        minAmount: Decimal.parse('10'),
      );

      await kit.viewModel.applyFilters(filters);

      final call = kit.transactions.calls.last;
      expect(call.offset, 0);
      expect(call.filters, filters);
      expect(kit.viewModel.filters, filters);
      expect(kit.viewModel.items, hasLength(30));
    });

    test('changing_the_person_in_the_sheet_reloads_only_once', () async {
      await started();
      kit.transactions.calls.clear();

      await kit.viewModel.applyFilters(
        const TransactionFilters(accountId: 'a3'),
        scope: const ScopeOption.person(bia),
      );

      expect(kit.transactions.calls, hasLength(1));
      expect(kit.transactions.calls.single.userId, 'm2');
      expect(kit.transactions.calls.single.filters.accountId, 'a3');
    });

    test('applying_with_the_same_person_does_not_change_the_choice', () async {
      await started();

      await kit.viewModel.applyFilters(
        const TransactionFilters(accountId: 'a1'),
        scope: ScopeOption.me(ana),
      );

      expect(kit.viewModel.scope?.kind, ScopeKind.me);
      expect(kit.transactions.calls.last.userId, 'm1');
    });

    test('removing_a_chip_keeps_the_others', () async {
      await started();
      await kit.viewModel.applyFilters(
        const TransactionFilters(
          accountId: 'a1',
          direction: TransactionDirection.debit,
        ),
      );

      await kit.viewModel.removeFilter(TransactionFilterKey.account);

      expect(kit.viewModel.filters.accountId, isNull);
      expect(kit.viewModel.filters.direction, TransactionDirection.debit);
      expect(kit.transactions.calls.last.filters.accountId, isNull);
    });

    test('clear_all_removes_the_search_and_the_filters', () async {
      await started();
      kit.viewModel.setSearch('uber');
      await kit.viewModel.applyFilters(
        const TransactionFilters(accountId: 'a1'),
      );

      await kit.viewModel.clearAll();

      expect(kit.viewModel.search, '');
      expect(kit.viewModel.filters.isEmpty, isTrue);
      expect(kit.viewModel.hasSearchOrFilters, isFalse);
      expect(kit.transactions.calls.last.search, '');
    });
  });

  group('connected bank', () {
    test('is_unknown_until_the_accounts_arrive', () {
      kit = TransactionsKit();

      expect(kit.viewModel.hasConnectedBank, isNull);
    });

    test('me_has_a_bank_when_an_account_is_mine', () async {
      await started();

      expect(kit.viewModel.hasConnectedBank, isTrue);
    });

    test('a_person_without_accounts_has_no_bank', () async {
      kit = TransactionsKit();
      kit.accounts.result = Result.success([
        kit.accounts.result.valueOrNull!.first,
      ]);
      await kit.viewModel.start();

      await kit.viewModel.selectScope(const ScopeOption.person(bia));

      expect(kit.viewModel.hasConnectedBank, isFalse);
    });

    test('the_house_has_a_bank_when_any_account_exists', () async {
      await started();

      await kit.viewModel.selectScope(const ScopeOption.house());

      expect(kit.viewModel.hasConnectedBank, isTrue);
    });

    test('a_house_without_any_account_has_no_bank', () async {
      kit = TransactionsKit();
      kit.accounts.result = const Result<List<BankAccount>>.success([]);
      await kit.viewModel.start();
      await kit.viewModel.selectScope(const ScopeOption.house());

      expect(kit.viewModel.hasConnectedBank, isFalse);
    });

    test('failed_accounts_leave_it_unknown_and_the_list_still_works', () async {
      kit = TransactionsKit();
      kit.accounts.result = const Result.failure(NetworkFailure());

      await kit.viewModel.start();

      expect(kit.viewModel.hasConnectedBank, isNull);
      expect(kit.viewModel.accountList, isEmpty);
      expect(kit.viewModel.items, isNotEmpty);
    });
  });

  group('people', () {
    test('finds_the_owner_of_a_transaction_and_its_color_place', () async {
      await started();

      expect(kit.viewModel.memberOf('m2'), bia);
      expect(kit.viewModel.memberIndexOf('m1'), 0);
      expect(kit.viewModel.memberIndexOf('m2'), 1);
      expect(kit.viewModel.memberOf('stranger'), isNull);
      expect(kit.viewModel.memberIndexOf('stranger'), 0);
    });
  });

  group('refresh', () {
    test('reload_keeps_the_list_on_screen_and_asks_again', () async {
      await started();
      kit.transactions.calls.clear();
      kit.accounts.calls = 0;

      await kit.viewModel.reload();

      expect(kit.transactions.calls.single.offset, 0);
      expect(kit.accounts.calls, 1);
      expect(kit.viewModel.items, hasLength(30));
    });

    test('reload_before_the_profile_starts_everything', () async {
      kit = TransactionsKit();

      await kit.viewModel.reload();

      expect(kit.viewModel.state, isA<UiSuccess<List<Transaction>>>());
    });
  });

  group('answers that arrive late', () {
    test('an_old_answer_does_not_overwrite_a_newer_one', () async {
      await started();
      // The answer for the house is held...
      kit.transactions.gate = Completer();
      final held = kit.transactions.gate!;
      final first = kit.viewModel.selectScope(const ScopeOption.house());
      // ...then the person chooses Bia, whose answer is immediate.
      kit.transactions.gate = null;
      kit.transactions.all = [makeTransaction(id: 'only-bia')];
      await kit.viewModel.selectScope(const ScopeOption.person(bia));

      held.complete(
        Result.success(
          PageResult<Transaction>(
            items: [makeTransaction(id: 'old-house')],
            limit: 30,
            offset: 0,
            total: 1,
          ),
        ),
      );
      await first;

      expect(kit.viewModel.items.map((t) => t.id), ['only-bia']);
    });
  });

  test('it_can_be_disposed_while_the_page_is_loading', () async {
    kit = TransactionsKit();
    kit.transactions.gate = Completer();
    final starting = kit.viewModel.start();
    await pumpEventQueue();

    kit.viewModel.dispose();
    kit.transactions.gate!.complete(
      Result.success(
        PageResult<Transaction>(items: [], limit: 30, offset: 0, total: 0),
      ),
    );

    await expectLater(starting, completes);
    // The tearDown disposes the kit: give it a fresh one.
    kit = TransactionsKit();
  });
}
