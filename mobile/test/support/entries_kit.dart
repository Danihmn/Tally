import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/storage/session_token_store.dart';
import 'package:mobile/core/utils/debouncer.dart';
import 'package:mobile/features/accounts/domain/usecases/get_bank_accounts.dart';
import 'package:mobile/features/entries/domain/usecases/search_entries.dart';
import 'package:mobile/features/entries/presentation/viewmodels/entries_view_model.dart';
import 'package:mobile/features/entries/presentation/viewmodels/linked_transactions_view_model.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/usecases/get_household_members.dart';
import 'package:mobile/features/household/domain/usecases/get_me.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';
import 'package:mobile/features/transactions/domain/usecases/search_transactions.dart';
import 'package:mobile/features/transactions/presentation/viewmodels/linked_entries_view_model.dart';

import 'fake_entries_repository.dart';
import 'fake_household_repository.dart';
import 'fake_transactions_repository.dart';
import 'fakes.dart';
import 'transactions_kit.dart';

/// Everything a test needs to build the entries ViewModels with fakes.
/// "Today" is 13 November 2026.
class EntriesKit {
  EntriesKit({List<Member> users = const [ana, bia]})
    : entries = FakeEntriesRepository(),
      transactions = FakeTransactionsRepository(),
      accounts = FakeAccountsRepository(),
      household = FakeHouseholdRepository(
        me: const Result<Member>.success(ana),
        users: Result<List<Member>>.success(users),
      ),
      notifier = SessionExpiredNotifier() {
    session = SessionController(
      tokenStore: SessionTokenStore(FakeSecureStorage()),
      expiredNotifier: notifier,
    );
    scope = HouseholdScopeController(
      getMe: GetMe(household),
      getMembers: GetHouseholdMembers(household),
      session: session,
    );
    viewModel = EntriesViewModel(
      scopeController: scope,
      searchEntries: SearchEntries(entries),
      getAccounts: GetBankAccounts(accounts),
      debouncer: Debouncer(),
      now: () => DateTime(2026, 11, 13, 9),
    );
  }

  final FakeEntriesRepository entries;
  final FakeTransactionsRepository transactions;
  final FakeAccountsRepository accounts;
  final FakeHouseholdRepository household;
  final SessionExpiredNotifier notifier;
  late final SessionController session;
  late final HouseholdScopeController scope;
  late final EntriesViewModel viewModel;

  /// The "Lançamento vinculado" ViewModel of a transaction.
  LinkedEntriesViewModel linkedEntries(String transactionId) =>
      LinkedEntriesViewModel(
        transactionId: transactionId,
        searchEntries: SearchEntries(entries),
        getAccounts: GetBankAccounts(accounts),
        scopeController: scope,
      );

  /// The "Transação do banco" ViewModel of an entry.
  LinkedTransactionsViewModel linkedTransactions(String entryId) =>
      LinkedTransactionsViewModel(
        entryId: entryId,
        searchTransactions: SearchTransactions(transactions),
        getAccounts: GetBankAccounts(accounts),
        scopeController: scope,
      );

  Future<void> dispose() async {
    viewModel.dispose();
    scope.dispose();
    session.dispose();
    await notifier.dispose();
  }
}
