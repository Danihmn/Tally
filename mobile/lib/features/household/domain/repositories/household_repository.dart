import 'package:mobile/core/result/result.dart';
import 'package:mobile/features/household/domain/entities/member.dart';

/// The logged person and the people of the same household.
abstract interface class HouseholdRepository {
  /// The logged user.
  Future<Result<Member>> getMe();

  /// Every user the API lists. The API does not filter by household, so the
  /// use case that needs only the household does it.
  Future<Result<List<Member>>> getUsers();
}
