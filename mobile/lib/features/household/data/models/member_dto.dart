import 'package:mobile/core/utils/json_parsing.dart';

/// A user as `GET /users` and `GET /users/me` send it. The fields the app
/// does not use (`email`, `created_at`) are left out.
class MemberDto {
  const MemberDto({
    required this.id,
    required this.firstName,
    required this.householdId,
  });

  /// Throws [FormatException] when a field is missing.
  factory MemberDto.fromJson(Map<String, dynamic> json) => MemberDto(
    id: requireString(json['id'], 'id'),
    firstName: requireString(json['first_name'], 'first_name'),
    householdId: requireString(json['household_id'], 'household_id'),
  );

  final String id;
  final String firstName;
  final String householdId;
}
