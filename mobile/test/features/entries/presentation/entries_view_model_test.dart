import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/features/entries/domain/entities/entry_filters.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';

import '../../../support/entries_kit.dart';
import '../../../support/entry_factory.dart';
import '../../../support/transactions_kit.dart';

void main() {
  late EntriesKit kit;

  Future<EntriesKit> started() async {
    kit = EntriesKit();
    await kit.viewModel.start();
    await pumpEventQueue();
    return kit;
  }

  tearDown(() => kit.dispose());

  group('start', () {
    test('loads_the_planned_entries_of_the_current_month_for_me', () async {
      await started();

      final call = kit.entries.calls.firstWhere((c) => c.limit == 30);
      expect(call.status, EntryStatus.planned);
      expect(call.referenceMonth, DateTime(2026, 11));
      expect(call.userId, 'm1');
      expect(call.filters.isEmpty, isTrue);
      expect(call.search, '');
      expect(kit.viewModel.items.map((e) => e.id), ['e1', 'e2', 'e3']);
      expect(kit.viewModel.total, 3);
    });

    test('counts_every_tab_with_the_same_month_and_person', () async {
      await started();

      expect(kit.viewModel.countOf(EntryStatus.planned), 3);
      expect(kit.viewModel.countOf(EntryStatus.reconciled), 1);
      expect(kit.viewModel.countOf(EntryStatus.cancelled), 1);
      final counting = kit.entries.calls.where((c) => c.limit == 1);
      expect(counting, hasLength(3));
      expect(counting.every((c) => c.userId == 'm1'), isTrue);
      expect(
        counting.every((c) => c.referenceMonth == DateTime(2026, 11)),
        isTrue,
      );
    });

    test('loads_the_accounts_beside_the_list', () async {
      await started();

      expect(kit.accounts.calls, 1);
      expect(kit.viewModel.accountOf('a1')?.displayName, 'Nubank');
      expect(kit.viewModel.accountOf(null), isNull);
    });

    test('a_failed_profile_is_the_state_and_makes_no_request', () async {
      kit = EntriesKit();
      kit.household.me = const Result.failure(NetworkFailure());

      await kit.viewModel.start();

      expect(kit.viewModel.profile, isA<UiError<HouseholdProfile>>());
      expect(kit.entries.calls, isEmpty);
    });

    test('a_failed_first_page_is_the_state_of_the_list', () async {
      kit = EntriesKit();
      kit.entries.forced = const Result.failure(ServerUnavailableFailure());

      await kit.viewModel.start();

      expect(kit.viewModel.state, isA<UiError<List<FinancialEntry>>>());
    });

    test('an_empty_page_is_the_empty_state', () async {
      kit = EntriesKit();
      kit.entries.all = [];

      await kit.viewModel.start();

      expect(kit.viewModel.state, isA<UiEmpty<List<FinancialEntry>>>());
    });
  });

  group('months', () {
    test('there_are_chips_for_three_months_back_the_current_and_the_next', () {
      kit = EntriesKit();

      expect(kit.viewModel.months, [
        DateTime(2026, 8),
        DateTime(2026, 9),
        DateTime(2026, 10),
        DateTime(2026, 11),
        DateTime(2026, 12),
      ]);
    });

    test('choosing_a_month_reloads_the_list_and_the_counts', () async {
      await started();
      kit.entries.calls.clear();

      await kit.viewModel.selectMonth(DateTime(2026, 10, 17));
      await pumpEventQueue();

      expect(kit.viewModel.month, DateTime(2026, 10));
      expect(kit.viewModel.items, isEmpty);
      expect(kit.viewModel.countOf(EntryStatus.planned), 0);
      expect(kit.entries.calls.where((c) => c.limit == 1), hasLength(3));
      expect(
        kit.entries.calls.every((c) => c.referenceMonth == DateTime(2026, 10)),
        isTrue,
      );
    });

    test('todos_asks_for_every_month', () async {
      await started();

      await kit.viewModel.selectMonth(null);
      await pumpEventQueue();

      expect(kit.entries.calls.last.referenceMonth, isNull);
      expect(kit.viewModel.items.map((e) => e.id), contains('e1'));
    });
  });

  group('tabs', () {
    test('choosing_a_tab_loads_that_status_and_keeps_the_counts', () async {
      await started();
      kit.entries.calls.clear();

      await kit.viewModel.selectTab(EntryStatus.reconciled);
      await pumpEventQueue();

      expect(kit.viewModel.tab, EntryStatus.reconciled);
      expect(kit.viewModel.items.map((e) => e.id), ['e4']);
      expect(kit.entries.calls.single.status, EntryStatus.reconciled);
      expect(kit.viewModel.countOf(EntryStatus.planned), 3);
    });

    test('choosing_the_same_tab_does_nothing', () async {
      await started();
      kit.entries.calls.clear();

      await kit.viewModel.selectTab(EntryStatus.planned);

      expect(kit.entries.calls, isEmpty);
    });
  });

  group('search and filters', () {
    test('the_search_waits_for_a_pause_and_then_reloads_everything', () {
      fakeAsync((async) {
        kit = EntriesKit();
        unawaited(kit.viewModel.start());
        async.flushMicrotasks();
        kit.entries.calls.clear();

        kit.viewModel.setSearch('alug');
        kit.viewModel.setSearch('aluguel');
        async.flushMicrotasks();
        expect(kit.entries.calls, isEmpty);
        expect(kit.viewModel.search, 'aluguel');

        async.elapse(const Duration(milliseconds: 400));
        async.flushMicrotasks();

        expect(kit.viewModel.items.map((e) => e.id), ['e1']);
        expect(kit.entries.calls.every((c) => c.search == 'aluguel'), isTrue);
        // one list call and three counts
        expect(kit.entries.calls, hasLength(4));
      });
    });

    test('clearing_the_search_reloads_without_it', () async {
      await started();
      kit.viewModel.setSearch('luz');
      kit.viewModel.clearSearch();
      await pumpEventQueue();

      expect(kit.viewModel.search, '');
      expect(kit.entries.calls.last.search, '');
    });

    test('applying_filters_sends_them_to_the_list_and_the_counts', () async {
      await started();
      kit.entries.calls.clear();
      final filters = EntryFilters(
        type: EntryType.expenses,
        minAmount: Decimal.parse('100'),
      );

      await kit.viewModel.applyFilters(filters);
      await pumpEventQueue();

      expect(kit.viewModel.filters, filters);
      expect(kit.entries.calls, hasLength(4));
      expect(kit.entries.calls.every((c) => c.filters == filters), isTrue);
    });

    test('removing_a_filter_reloads_without_it', () async {
      await started();
      await kit.viewModel.applyFilters(
        const EntryFilters(type: EntryType.expenses, accountId: 'a1'),
      );

      await kit.viewModel.removeFilter(EntryFilterKey.type);
      await pumpEventQueue();

      expect(kit.viewModel.filters, const EntryFilters(accountId: 'a1'));
    });

    test('clear_all_keeps_the_tab_and_the_month', () async {
      await started();
      await kit.viewModel.selectTab(EntryStatus.reconciled);
      kit.viewModel.setSearch('x');
      await kit.viewModel.applyFilters(
        const EntryFilters(type: EntryType.revenues),
      );

      await kit.viewModel.clearAll();
      await pumpEventQueue();

      expect(kit.viewModel.hasSearchOrFilters, isFalse);
      expect(kit.viewModel.tab, EntryStatus.reconciled);
      expect(kit.viewModel.month, DateTime(2026, 11));
    });
  });

  group('person', () {
    test('choosing_another_person_reloads_the_list_and_the_counts', () async {
      await started();
      kit.entries.calls.clear();

      await kit.viewModel.selectScope(const ScopeOption.person(bia));
      await pumpEventQueue();

      expect(kit.entries.calls.every((c) => c.userId == 'm2'), isTrue);
      expect(kit.entries.calls, hasLength(4));
    });

    test('the_house_asks_without_a_person', () async {
      await started();

      await kit.viewModel.selectScope(const ScopeOption.house());
      await pumpEventQueue();

      expect(kit.entries.calls.last.userId, isNull);
    });

    test('a_change_made_on_another_screen_reloads_this_one', () async {
      await started();
      kit.entries.calls.clear();

      kit.scope.select(const ScopeOption.house());
      await pumpEventQueue();

      expect(kit.entries.calls, isNotEmpty);
      expect(kit.entries.calls.every((c) => c.userId == null), isTrue);
    });

    test('the_sheet_can_change_the_person_and_the_filters_together', () async {
      await started();
      kit.entries.calls.clear();

      await kit.viewModel.applyFilters(
        const EntryFilters(type: EntryType.expenses),
        scope: const ScopeOption.person(bia),
      );
      await pumpEventQueue();

      expect(kit.entries.calls.every((c) => c.userId == 'm2'), isTrue);
      expect(
        kit.entries.calls.every((c) => c.filters.type == EntryType.expenses),
        isTrue,
      );
    });

    test('the_owner_and_the_color_come_from_the_house', () async {
      await started();

      expect(kit.viewModel.memberOf('m2')?.firstName, 'Bia');
      expect(kit.viewModel.memberOf('nope'), isNull);
      expect(kit.viewModel.memberIndexOf('m2'), 1);
      expect(kit.viewModel.memberIndexOf('nope'), 0);
    });
  });

  group('paging and refresh', () {
    test('the_next_page_is_asked_with_the_offset', () async {
      kit = EntriesKit();
      kit.entries.all = [
        for (var i = 0; i < 45; i++)
          makeEntry(id: 'x$i', description: 'Item $i'),
      ];
      await kit.viewModel.start();
      await pumpEventQueue();
      expect(kit.viewModel.items, hasLength(30));
      expect(kit.viewModel.hasMore, isTrue);

      await kit.viewModel.loadMore();

      expect(kit.viewModel.items, hasLength(45));
      expect(kit.viewModel.total, 45);
    });

    test('reload_loads_the_accounts_the_counts_and_the_list_again', () async {
      await started();
      kit.entries.calls.clear();

      await kit.viewModel.reload();
      await pumpEventQueue();

      expect(kit.accounts.calls, 2);
      expect(kit.entries.calls, hasLength(4));
    });
  });

  group('today', () {
    test('is_the_local_day_without_the_time', () {
      kit = EntriesKit();

      expect(kit.viewModel.today, DateTime(2026, 11, 13));
    });
  });
}
