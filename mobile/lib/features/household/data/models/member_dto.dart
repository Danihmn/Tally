import 'package:mobile/core/utils/json_parsing.dart';

/// A user as `GET /users` and `GET /users/me` send it. The field the app does
/// not use (`created_at`) is left out.
class MemberDto {
  const MemberDto({
    required this.id,
    required this.firstName,
    required this.householdId,
    this.lastName,
    this.surname,
    this.email,
  });

  /// Throws [FormatException] when a required field is missing. `last_name`,
  /// `surname` (the nickname) and `email` may be absent or `null`.
  factory MemberDto.fromJson(Map<String, dynamic> json) => MemberDto(
    id: requireString(json['id'], 'id'),
    firstName: requireString(json['first_name'], 'first_name'),
    householdId: requireString(json['household_id'], 'household_id'),
    lastName: optionalString(json['last_name']),
    surname: optionalString(json['surname']),
    email: optionalString(json['email']),
  );

  final String id;
  final String firstName;
  final String householdId;
  final String? lastName;
  final String? surname;
  final String? email;
}
