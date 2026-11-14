import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/storage/session_token_store.dart';
import 'package:mobile/core/utils/debouncer.dart';
import 'package:mobile/features/accounts/domain/usecases/get_bank_accounts.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/usecases/get_household_members.dart';
import 'package:mobile/features/household/domain/usecases/get_me.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';
import 'package:mobile/features/transactions/domain/transactions_filter_request.dart';
import 'package:mobile/features/transactions/domain/usecases/search_transactions.dart';
import 'package:mobile/features/transactions/presentation/viewmodels/transactions_view_model.dart';

import 'fake_household_repository.dart';
import 'fake_transactions_repository.dart';
import 'fakes.dart';

const ana = Member(id: 'm1', firstName: 'Ana', householdId: 'h1');
const bia = Member(id: 'm2', firstName: 'Bia', householdId: 'h1');

/// Everything a test needs to build the transactions ViewModel with fakes.
/// "Today" is 13 November 2026.
class TransactionsKit {
  TransactionsKit({List<Member> users = const [ana, bia]})
    : transactions = FakeTransactionsRepository(),
      accounts = FakeAccountsRepository(),
      household = FakeHouseholdRepository(
        me: const Result<Member>.success(ana),
        users: Result<List<Member>>.success(users),
      ),
      filterRequest = TransactionsFilterRequest(),
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
    viewModel = TransactionsViewModel(
      scopeController: scope,
      searchTransactions: SearchTransactions(transactions),
      getAccounts: GetBankAccounts(accounts),
      filterRequest: filterRequest,
      debouncer: Debouncer(),
      now: () => DateTime(2026, 11, 13, 9),
    );
  }

  final FakeTransactionsRepository transactions;
  final FakeAccountsRepository accounts;
  final FakeHouseholdRepository household;
  final TransactionsFilterRequest filterRequest;
  final SessionExpiredNotifier notifier;
  late final SessionController session;
  late final HouseholdScopeController scope;
  late final TransactionsViewModel viewModel;

  Future<void> dispose() async {
    viewModel.dispose();
    filterRequest.dispose();
    scope.dispose();
    session.dispose();
    await notifier.dispose();
  }
}
