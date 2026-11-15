import 'package:flutter/foundation.dart';
import 'package:mobile/core/result/result.dart';
import 'package:mobile/core/state/ui_state.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/entities/pluggy_credentials.dart';
import 'package:mobile/features/household/domain/entities/user_changes.dart';
import 'package:mobile/features/household/domain/entities/user_draft.dart';
import 'package:mobile/features/household/domain/usecases/create_user.dart';
import 'package:mobile/features/household/domain/usecases/update_pluggy_credentials.dart';
import 'package:mobile/features/household/domain/usecases/update_user.dart';
import 'package:mobile/features/household/presentation/viewmodels/household_scope_controller.dart';

/// The people of the house, for the "Usuários" screens: the list, adding a
/// person, editing one and changing the Pluggy credentials.
///
/// The list is the one the whole app shares ([HouseholdScopeController]), so
/// a change shows up in the filters and on the home too. Nobody is deleted.
class UsersViewModel extends ChangeNotifier {
  UsersViewModel({
    required this._scope,
    required this._createUser,
    required this._updateUser,
    required this._updateCredentials,
  }) {
    _scope.addListener(notifyListeners);
  }

  final HouseholdScopeController _scope;
  final CreateUser _createUser;
  final UpdateUser _updateUser;
  final UpdatePluggyCredentials _updateCredentials;

  UiState<HouseholdProfile> get profile => _scope.profile;

  /// Everybody of the house, the logged person first.
  List<Member> get members => _scope.profileData?.members ?? const [];

  Member? get me => _scope.profileData?.me;

  /// The person with [id], or `null` when they are not in the list (anymore).
  Member? memberById(String id) {
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  Future<void> load() => _scope.ensureLoaded();

  Future<void> retry() => _scope.reload();

  Future<Result<Member>> create(UserDraft draft) async {
    final result = await _createUser(draft);
    if (result.isSuccess) await _scope.refreshMembers();
    return result;
  }

  Future<Result<Member>> update(String id, UserChanges changes) async {
    final result = await _updateUser(id, changes);
    if (result.isSuccess) await _scope.refreshMembers();
    return result;
  }

  /// Nothing to reload: the list does not carry the credentials.
  Future<Result<void>> updateCredentials(
    String id,
    PluggyCredentials credentials,
  ) => _updateCredentials(id, credentials);

  @override
  void dispose() {
    _scope.removeListener(notifyListeners);
    super.dispose();
  }
}
