import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/storage/session_token_store.dart';
import 'package:mobile/features/accounts/domain/usecases/get_account_balances.dart';
import 'package:mobile/features/accounts/domain/usecases/get_total_balance.dart';
import 'package:mobile/features/accounts/domain/usecases/update_account_settings.dart';
import 'package:mobile/features/accounts/presentation/viewmodels/accounts_view_model.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/usecases/get_household_members.dart';
import 'package:mobile/features/household/domain/usecases/get_me.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';

import 'fake_household_repository.dart';
import 'fake_transactions_repository.dart';
import 'fakes.dart';
import 'transactions_kit.dart';

/// Everything a test needs to build the Contas ViewModel with fakes.
class AccountsKit {
  AccountsKit({List<Member> users = const [ana, bia]})
    : accounts = FakeAccountsRepository(),
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
    viewModel = AccountsViewModel(
      scopeController: scope,
      getBalances: GetAccountBalances(accounts),
      getTotal: GetTotalBalance(accounts),
      updateSettings: UpdateAccountSettings(accounts),
    );
  }

  final FakeAccountsRepository accounts;
  final FakeHouseholdRepository household;
  final SessionExpiredNotifier notifier;
  late final SessionController session;
  late final HouseholdScopeController scope;
  late final AccountsViewModel viewModel;

  Future<void> dispose() async {
    viewModel.dispose();
    scope.dispose();
    session.dispose();
    await notifier.dispose();
  }
}
