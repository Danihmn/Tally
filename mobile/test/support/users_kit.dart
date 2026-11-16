import 'package:mobile/core/network/session_expired_notifier.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/storage/session_token_store.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/usecases/create_user.dart';
import 'package:mobile/features/household/domain/usecases/get_household_members.dart';
import 'package:mobile/features/household/domain/usecases/get_me.dart';
import 'package:mobile/features/household/domain/usecases/update_pluggy_credentials.dart';
import 'package:mobile/features/household/domain/usecases/update_user.dart';
import 'package:mobile/features/household/domain/usecases/update_user_password.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';
import 'package:mobile/features/household/presentation/viewmodels/users_view_model.dart';

import 'fake_household_repository.dart';
import 'fakes.dart';

/// The logged person, with a nickname.
const aninha = Member(
  id: 'm1',
  firstName: 'Ana',
  lastName: 'Souza',
  surname: 'Aninha',
  email: 'ana@casa.com',
  householdId: 'h1',
);

/// Another person of the house, without a nickname.
const bia = Member(
  id: 'm2',
  firstName: 'Bia',
  lastName: 'Lima',
  email: 'bia@casa.com',
  householdId: 'h1',
);

/// The "Usuários" ViewModel over a fake repository and the shared list of
/// people. The house has [aninha] (logged) and [bia].
class UsersKit {
  UsersKit({List<Member> users = const [aninha, bia]})
    : household = FakeHouseholdRepository(
        me: const Result<Member>.success(aninha),
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
    viewModel = UsersViewModel(
      scope: scope,
      createUser: CreateUser(household),
      updateUser: UpdateUser(household),
      updateCredentials: UpdatePluggyCredentials(household),
      updatePassword: UpdateUserPassword(household),
    );
  }

  final FakeHouseholdRepository household;
  final SessionExpiredNotifier notifier;
  late final SessionController session;
  late final HouseholdScopeController scope;
  late final UsersViewModel viewModel;

  Future<void> dispose() async {
    scope.dispose();
    session.dispose();
    await notifier.dispose();
  }
}
