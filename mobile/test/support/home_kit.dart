import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/storage/session_token_store.dart';
import 'package:mobile/features/auth/domain/usecases/logout.dart';
import 'package:mobile/features/home/domain/usecases/get_daily_spending.dart';
import 'package:mobile/features/home/domain/usecases/get_planning_progress.dart';
import 'package:mobile/features/home/domain/usecases/get_spending_by_member.dart';
import 'package:mobile/features/home/domain/usecases/get_spending_summary.dart';
import 'package:mobile/features/home/domain/usecases/get_top_expenses.dart';
import 'package:mobile/features/home/domain/usecases/get_upcoming_entries.dart';
import 'package:mobile/features/home/presentation/viewmodels/home_view_model.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/usecases/get_household_members.dart';
import 'package:mobile/features/household/domain/usecases/get_me.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';

import 'fake_auth_repository.dart';
import 'fake_home_repository.dart';
import 'fake_household_repository.dart';
import 'fakes.dart';

const ana = Member(id: 'm1', firstName: 'Ana', householdId: 'h1');
const bia = Member(id: 'm2', firstName: 'Bia', householdId: 'h1');
const caio = Member(id: 'm3', firstName: 'Caio', householdId: 'h1');

/// Everything a test needs to build the ViewModel with fakes.
class HomeKit {
  HomeKit({DateTime? now, List<Member> users = const [ana, bia]})
    : home = FakeHomeRepository(),
      household = FakeHouseholdRepository(
        me: const Result<Member>.success(ana),
        users: Result<List<Member>>.success(users),
      ),
      auth = FakeAuthRepository(),
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
    viewModel = HomeViewModel(
      scopeController: scope,
      getSummary: GetSpendingSummary(home),
      getPlanning: GetPlanningProgress(home),
      getByMember: GetSpendingByMember(home),
      getDaily: GetDailySpending(home),
      getTopExpenses: GetTopExpenses(home),
      getUpcoming: GetUpcomingEntries(home),
      logout: Logout(auth),
      session: session,
      now: () => now ?? DateTime(2026, 11, 13, 9, 30),
    );
  }

  final FakeHomeRepository home;
  final FakeHouseholdRepository household;
  final FakeAuthRepository auth;
  final SessionExpiredNotifier notifier;
  late final SessionController session;
  late final HouseholdScopeController scope;
  late final HomeViewModel viewModel;

  Future<void> dispose() async {
    viewModel.dispose();
    scope.dispose();
    session.dispose();
    await notifier.dispose();
  }
}
