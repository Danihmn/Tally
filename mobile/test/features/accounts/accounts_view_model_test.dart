import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/features/accounts/domain/entities/account_balance.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';

import '../../support/accounts_kit.dart';
import '../../support/transactions_kit.dart';

void main() {
  late AccountsKit kit;

  Future<AccountsKit> started() async {
    kit = AccountsKit();
    await kit.viewModel.start();
    return kit;
  }

  tearDown(() => kit.dispose());

  group('start', () {
    test('loads_the_accounts_and_the_two_totals_for_me', () async {
      await started();

      expect(kit.accounts.balanceCalls, ['m1']);
      expect(kit.accounts.totalCalls, [
        (AccountKind.bank, 'm1'),
        (AccountKind.credit, 'm1'),
      ]);
      expect(
        (kit.viewModel.bankTotal as UiSuccess<Decimal>).data,
        Decimal.parse('2301.45'),
      );
      expect(
        (kit.viewModel.cardTotal as UiSuccess<Decimal>).data,
        Decimal.parse('150.00'), // the bills due next month
      );
    });

    test('the_bills_are_the_ones_due_next_month', () async {
      await started();

      expect(kit.viewModel.billMonth, DateTime(2026, 12));
    });

    test('splits_the_list_in_accounts_and_cards', () async {
      await started();

      expect(kit.viewModel.banks.map((a) => a.id), ['a1']);
      expect(kit.viewModel.cards.map((a) => a.id), ['a2']);
      expect(kit.viewModel.tab, AccountKind.bank);
      expect(kit.viewModel.visible.map((a) => a.id), ['a1']);
    });

    test('a_failed_profile_is_the_state_and_makes_no_request', () async {
      kit = AccountsKit();
      kit.household.me = const Result.failure(NetworkFailure());

      await kit.viewModel.start();

      expect(kit.viewModel.profile, isA<UiError<HouseholdProfile>>());
      expect(kit.accounts.balanceCalls, isEmpty);
      expect(kit.accounts.totalCalls, isEmpty);
    });

    test('nothing_connected_is_the_empty_state', () async {
      kit = AccountsKit();
      kit.accounts.balances = [];

      await kit.viewModel.start();

      expect(kit.viewModel.list, isA<UiEmpty<List<AccountBalance>>>());
      expect(kit.viewModel.hasNoConnection, isTrue);
    });
  });

  group('each part fails on its own', () {
    test('a_failed_list_keeps_the_totals', () async {
      kit = AccountsKit();
      kit.accounts.balancesForced = const Result.failure(
        ServerUnavailableFailure(),
      );

      await kit.viewModel.start();

      expect(kit.viewModel.list, isA<UiError<List<AccountBalance>>>());
      expect(kit.viewModel.bankTotal, isA<UiSuccess<Decimal>>());
      expect(kit.viewModel.hasNoConnection, isNull);
    });

    test('failed_totals_keep_the_list_and_retry_loads_them', () async {
      kit = AccountsKit();
      kit.accounts.totalForced = const Result.failure(NetworkFailure());
      await kit.viewModel.start();
      expect(kit.viewModel.bankTotal, isA<UiError<Decimal>>());
      expect(kit.viewModel.cardTotal, isA<UiError<Decimal>>());
      expect(kit.viewModel.list, isA<UiSuccess<List<AccountBalance>>>());

      kit.accounts.totalForced = null;
      await kit.viewModel.retryTotals();

      expect(kit.viewModel.bankTotal, isA<UiSuccess<Decimal>>());
    });

    test('retrying_the_list_loads_it_again', () async {
      kit = AccountsKit();
      kit.accounts.balancesForced = const Result.failure(NetworkFailure());
      await kit.viewModel.start();

      kit.accounts.balancesForced = null;
      await kit.viewModel.retryList();

      expect(kit.viewModel.list, isA<UiSuccess<List<AccountBalance>>>());
    });
  });

  group('tab', () {
    test('choosing_the_cards_tab_shows_the_cards_without_a_request', () async {
      await started();
      final calls = kit.accounts.balanceCalls.length;

      kit.viewModel.selectTab(AccountKind.credit);

      expect(kit.viewModel.tab, AccountKind.credit);
      expect(kit.viewModel.visible.map((a) => a.id), ['a2']);
      expect(kit.accounts.balanceCalls, hasLength(calls));
    });
  });

  group('person', () {
    test('choosing_another_person_loads_everything_again', () async {
      await started();

      await kit.viewModel.selectScope(const ScopeOption.person(bia));

      expect(kit.accounts.balanceCalls.last, 'm2');
      expect(kit.accounts.totalCalls.last.$2, 'm2');
      expect(kit.viewModel.banks.map((a) => a.id), ['a3']);
      expect(kit.viewModel.cards.map((a) => a.id), ['a4']);
    });

    test('the_house_asks_without_a_person', () async {
      await started();

      await kit.viewModel.selectScope(const ScopeOption.house());

      expect(kit.accounts.balanceCalls.last, isNull);
      expect(kit.viewModel.banks, hasLength(2));
      expect(
        (kit.viewModel.bankTotal as UiSuccess<Decimal>).data,
        Decimal.parse('3501.45'),
      );
    });

    test('a_change_made_on_another_screen_reloads_this_one', () async {
      await started();
      kit.accounts.balanceCalls.clear();

      kit.scope.select(const ScopeOption.house());
      await pumpEventQueue();

      expect(kit.accounts.balanceCalls, [null]);
    });

    test('the_owner_and_the_color_come_from_the_house', () async {
      await started();

      expect(kit.viewModel.memberOf('m2')?.firstName, 'Bia');
      expect(kit.viewModel.memberOf('nope'), isNull);
      expect(kit.viewModel.memberIndexOf('m2'), 1);
      expect(kit.viewModel.memberIndexOf('nope'), 0);
    });
  });

  group('reload', () {
    test('pull_to_refresh_loads_the_list_and_the_totals_again', () async {
      await started();
      kit.accounts.balanceCalls.clear();
      kit.accounts.totalCalls.clear();

      await kit.viewModel.reload();

      expect(kit.accounts.balanceCalls, hasLength(1));
      expect(kit.accounts.totalCalls, hasLength(2));
    });
  });

  group('salary account', () {
    test('turning_it_on_saves_the_code_and_loads_everything_again', () async {
      await started();
      final account = kit.viewModel.banks.single;
      kit.accounts.balanceCalls.clear();
      kit.accounts.totalCalls.clear();

      final failure = await kit.viewModel.setSalaryAccount(
        account,
        enabled: true,
        bankCode: '001',
      );

      expect(failure, isNull);
      expect(kit.accounts.updateCalls, [('a1', true, '001')]);
      expect(kit.accounts.balanceCalls, ['m1']);
      expect(kit.accounts.totalCalls, hasLength(2));
      final saved = kit.viewModel.banks.single;
      expect(saved.outgoingTransfersAreIncome, isTrue);
      expect(saved.bankCode, '001');
      expect(kit.viewModel.isSaving('a1'), isFalse);
    });

    test('turning_it_on_without_a_code_lets_the_server_find_it', () async {
      await started();

      final failure = await kit.viewModel.setSalaryAccount(
        kit.viewModel.banks.single,
        enabled: true,
      );

      expect(failure, isNull);
      expect(kit.accounts.updateCalls, [('a1', true, null)]);
      expect(kit.viewModel.banks.single.bankCode, '001');
    });

    test('turning_it_off_does_not_send_a_code', () async {
      await started();

      await kit.viewModel.setSalaryAccount(
        kit.viewModel.banks.single,
        enabled: false,
        bankCode: '001',
      );

      expect(kit.accounts.updateCalls, [('a1', false, null)]);
    });

    test('a_failure_is_returned_and_nothing_is_reloaded', () async {
      await started();
      kit.accounts.updateForced = const Result.failure(ValidationFailure());
      kit.accounts.balanceCalls.clear();

      final failure = await kit.viewModel.setSalaryAccount(
        kit.viewModel.banks.single,
        enabled: true,
        bankCode: '001',
      );

      expect(failure, isA<ValidationFailure>());
      expect(kit.accounts.balanceCalls, isEmpty);
      expect(kit.viewModel.banks.single.outgoingTransfersAreIncome, isFalse);
      expect(kit.viewModel.isSaving('a1'), isFalse);
    });
  });
}
