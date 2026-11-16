import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/storage/session_token_store.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/usecases/get_household_members.dart';
import 'package:mobile/features/household/domain/usecases/get_me.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';
import 'package:mobile/features/recurrences/domain/usecases/create_recurrence.dart';
import 'package:mobile/features/recurrences/domain/usecases/delete_recurrence.dart';
import 'package:mobile/features/recurrences/domain/usecases/list_recurrences.dart';
import 'package:mobile/features/recurrences/domain/usecases/provision_next_month.dart';
import 'package:mobile/features/recurrences/domain/usecases/set_recurrence_status.dart';
import 'package:mobile/features/recurrences/domain/usecases/update_recurrence.dart';
import 'package:mobile/features/recurrences/presentation/viewmodels/recurrences_view_model.dart';

import 'fake_household_repository.dart';
import 'fake_recurrences_repository.dart';
import 'fakes.dart';

/// The logged person and the other person of the house.
const recurrenceAna = Member(id: 'm1', firstName: 'Ana', householdId: 'h1');
const recurrenceBia = Member(id: 'm2', firstName: 'Bia', householdId: 'h1');

/// The recurrences ViewModel over a fake repository. "Today" is 13 November
/// 2026, so the next month is December. The house has Ana (logged) and Bia.
class RecurrencesKit {
  RecurrencesKit({DateTime? now})
    : repository = FakeRecurrencesRepository(),
      household = FakeHouseholdRepository(
        me: const Result<Member>.success(recurrenceAna),
        users: const Result<List<Member>>.success([
          recurrenceAna,
          recurrenceBia,
        ]),
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
    viewModel = RecurrencesViewModel(
      listRecurrences: ListRecurrences(repository),
      createRecurrence: CreateRecurrence(repository),
      updateRecurrence: UpdateRecurrence(repository),
      setRecurrenceStatus: SetRecurrenceStatus(repository),
      deleteRecurrence: DeleteRecurrence(repository),
      provisionNextMonth: ProvisionNextMonth(repository),
      scopeController: scope,
      now: () => now ?? DateTime(2026, 11, 13, 9),
    );
  }

  final FakeRecurrencesRepository repository;
  final FakeHouseholdRepository household;
  final SessionExpiredNotifier notifier;
  late final SessionController session;
  late final HouseholdScopeController scope;
  late final RecurrencesViewModel viewModel;

  /// Disposes the shared list of people (the ViewModel is disposed by its
  /// screen or by the test).
  Future<void> dispose() async {
    scope.dispose();
    session.dispose();
    await notifier.dispose();
  }
}
