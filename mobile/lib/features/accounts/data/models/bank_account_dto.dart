import 'package:mobile/core/utils/json_parsing.dart';

/// An account as `GET /bank-accounts` sends it. The fields the app does not
/// use (balance, holder, dates) are left out.
class BankAccountDto {
  const BankAccountDto({
    required this.id,
    required this.userId,
    required this.name,
    required this.marketingName,
    required this.number,
    required this.type,
  });

  /// Throws [FormatException] when a required field is missing.
  factory BankAccountDto.fromJson(Map<String, dynamic> json) => BankAccountDto(
    id: requireString(json['id'], 'id'),
    userId: requireString(json['user_id'], 'user_id'),
    name: requireString(json['name'], 'name'),
    marketingName: json['marketing_name'] as String?,
    number: json['number'] as String? ?? '',
    type: requireString(json['type'], 'type'),
  );

  final String id;
  final String userId;
  final String name;
  final String? marketingName;
  final String number;

  /// `BANK` or `CREDIT`.
  final String type;
}
