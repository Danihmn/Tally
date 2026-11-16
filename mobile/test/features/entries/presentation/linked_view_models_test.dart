import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/features/entries/domain/entities/financial_entry.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';

import '../../../support/entries_kit.dart';
import '../../../support/entry_factory.dart';
import '../../../support/transaction_factory.dart';

void main() {
  late EntriesKit kit;

  setUp(() async {
    kit = EntriesKit();
    await kit.scope.ensureLoaded();
  });

  tearDown(() => kit.dispose());

  group('LinkedEntriesViewModel', () {
    test('loads_the_entries_matched_with_the_transaction', () async {
      kit.entries.byTransaction['t1'] = [
        makeEntry(id: 'e9', status: EntryStatus.reconciled),
      ];
      final viewModel = kit.linkedEntries('t1');

      await viewModel.load();

      final state = viewModel.state as UiSuccess<List<FinancialEntry>>;
      expect(state.data.single.id, 'e9');
      expect(kit.entries.calls.single.transactionId, 't1');
      viewModel.dispose();
    });

    test('a_transaction_without_a_match_is_the_empty_state', () async {
      final viewModel = kit.linkedEntries('t1');

      await viewModel.load();

      expect(viewModel.state, isA<UiEmpty<List<FinancialEntry>>>());
      viewModel.dispose();
    });

    test('a_failure_is_the_state_and_loading_again_can_fix_it', () async {
      kit.entries.forced = const Result.failure(NetworkFailure());
      final viewModel = kit.linkedEntries('t1');

      await viewModel.load();
      expect(viewModel.state, isA<UiError<List<FinancialEntry>>>());

      kit.entries.forced = null;
      kit.entries.byTransaction['t1'] = [makeEntry()];
      await viewModel.load();

      expect(viewModel.state, isA<UiSuccess<List<FinancialEntry>>>());
      viewModel.dispose();
    });

    test('gives_the_account_and_the_owner_of_an_entry', () async {
      final viewModel = kit.linkedEntries('t1');
      await viewModel.load();

      expect(viewModel.accountOf('a2')?.displayName, 'Itaú Card');
      expect(viewModel.accountOf(null), isNull);
      expect(viewModel.memberOf('m2')?.firstName, 'Bia');
      expect(viewModel.memberIndexOf('m2'), 1);
      expect(viewModel.memberIndexOf('nope'), 0);
      viewModel.dispose();
    });

    test('a_failed_account_list_only_leaves_the_name_out', () async {
      kit.accounts.result = const Result.failure(NetworkFailure());
      kit.entries.byTransaction['t1'] = [makeEntry()];
      final viewModel = kit.linkedEntries('t1');

      await viewModel.load();

      expect(viewModel.state, isA<UiSuccess<List<FinancialEntry>>>());
      expect(viewModel.accountOf('a1'), isNull);
      viewModel.dispose();
    });
  });

  group('LinkedEntriesViewModel link and unlink', () {
    test('candidates_are_planned_of_the_type_and_not_linked', () async {
      kit.entries.byTransaction['t1'] = [
        makeEntry(id: 'e1', status: EntryStatus.reconciled),
      ];
      final viewModel = kit.linkedEntries('t1');
      await viewModel.load();

      final result = await viewModel.candidates(
        type: EntryType.expenses,
        search: 'net',
      );

      final call = kit.entries.calls.last;
      expect(call.status, EntryStatus.planned);
      expect(call.filters.type, EntryType.expenses);
      expect(call.search, 'net');
      expect(call.transactionId, isNull);
      expect(result.valueOrNull!.map((e) => e.id), isNot(contains('e1')));
      viewModel.dispose();
    });

    test('linking_sends_the_pair_and_reads_the_block_again', () async {
      final viewModel = kit.linkedEntries('t1');
      await viewModel.load();
      final calls = kit.entries.calls.length;

      final failure = await viewModel.link('e2');

      expect(failure, isNull);
      expect(kit.transactions.linked.single, ('t1', 'e2'));
      expect(kit.entries.calls.length, calls + 1);
      viewModel.dispose();
    });

    test('unlinking_sends_the_pair_and_reads_the_block_again', () async {
      final viewModel = kit.linkedEntries('t1');
      await viewModel.load();
      final calls = kit.entries.calls.length;

      final failure = await viewModel.unlink('e2');

      expect(failure, isNull);
      expect(kit.transactions.unlinked.single, ('t1', 'e2'));
      expect(kit.entries.calls.length, calls + 1);
      viewModel.dispose();
    });

    test('a_failed_link_is_returned_and_nothing_is_read_again', () async {
      kit.transactions.linkResult = const Result.failure(ConflictFailure());
      final viewModel = kit.linkedEntries('t1');
      await viewModel.load();
      final calls = kit.entries.calls.length;

      final failure = await viewModel.link('e2');

      expect(failure, const ConflictFailure());
      expect(kit.entries.calls.length, calls);
      viewModel.dispose();
    });
  });

  group('LinkedTransactionsViewModel', () {
    test('asks_for_the_transactions_matched_with_the_entry', () async {
      final viewModel = kit.linkedTransactions('e4');

      await viewModel.load();

      expect(kit.transactions.calls.single.financialEntryId, 'e4');
      expect(viewModel.state, isA<UiSuccess<List<Transaction>>>());
      viewModel.dispose();
    });

    test('nothing_found_is_the_empty_state', () async {
      kit.transactions.all = [];
      final viewModel = kit.linkedTransactions('e4');

      await viewModel.load();

      expect(viewModel.state, isA<UiEmpty<List<Transaction>>>());
      viewModel.dispose();
    });

    test('a_failure_is_the_state', () async {
      kit.transactions.forced = const Result.failure(
        ServerUnavailableFailure(),
      );
      final viewModel = kit.linkedTransactions('e4');

      await viewModel.load();

      expect(viewModel.state, isA<UiError<List<Transaction>>>());
      viewModel.dispose();
    });

    test('gives_the_account_and_the_owner_of_a_transaction', () async {
      final viewModel = kit.linkedTransactions('e4');
      await viewModel.load();

      expect(viewModel.accountOf('a1')?.displayName, 'Nubank');
      expect(viewModel.memberOf('m1')?.firstName, 'Ana');
      expect(makeTransaction().ownerId, 'm1');
      viewModel.dispose();
    });
  });
}
