import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/domain/entities/member.dart';
import 'package:mobile/features/household/domain/entities/pluggy_credentials.dart';
import 'package:mobile/features/household/domain/entities/user_changes.dart';
import 'package:mobile/features/household/domain/entities/user_draft.dart';

/// The logged person and the people of the same household.
abstract interface class HouseholdRepository {
  /// The logged user.
  Future<Result<Member>> getMe();

  /// Every user the API lists. The API does not filter by household, so the
  /// use case that needs only the household does it.
  Future<Result<List<Member>>> getUsers();

  /// Adds a person to the house of the logged user.
  Future<Result<Member>> createUser(UserDraft draft);

  /// Edits the name, nickname and e-mail of a person.
  Future<Result<Member>> updateUser(String id, UserChanges changes);

  /// Replaces the Pluggy credentials of a person.
  Future<Result<void>> updatePluggyCredentials(
    String id,
    PluggyCredentials credentials,
  );
}
