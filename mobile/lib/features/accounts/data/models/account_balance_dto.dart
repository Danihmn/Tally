import 'package:decimal/decimal.dart';
import 'package:mobile/core/utils/json_parsing.dart';

/// The credit data of a card inside `GET /bank-accounts/balances`.
class CreditInfoDto {
  const CreditInfoDto({
    required this.creditLimit,
    required this.availableCreditLimit,
    required this.dueDate,
    required this.closeDate,
  });

  factory CreditInfoDto.fromJson(Map<String, dynamic> json) => CreditInfoDto(
    creditLimit: parseDecimalOrNull(json['credit_limit']),
    availableCreditLimit: parseDecimalOrNull(json['available_credit_limit']),
    dueDate: parseDateTimeOrNull(json['balance_due_date']),
    closeDate: parseDateTimeOrNull(json['balance_close_date']),
  );

  final Decimal? creditLimit;
  final Decimal? availableCreditLimit;
  final DateTime? dueDate;
  final DateTime? closeDate;
}

/// An account or card as `GET /bank-accounts/balances` sends it.
class AccountBalanceDto {
  const AccountBalanceDto({
    required this.id,
    required this.userId,
    required this.type,
    required this.name,
    required this.marketingName,
    required this.number,
    required this.balance,
    required this.credit,
    this.outgoingTransfersAreIncome = false,
    this.bankCode,
  });

  /// Throws [FormatException] when a required field is missing or invalid.
  factory AccountBalanceDto.fromJson(Map<String, dynamic> json) {
    final credit = json['credit'];
    return AccountBalanceDto(
      id: requireString(json['id'], 'id'),
      userId: requireString(json['user_id'], 'user_id'),
      type: requireString(json['type'], 'type'),
      name: requireString(json['name'], 'name'),
      marketingName: json['marketing_name'] as String?,
      number: json['number'] as String? ?? '',
      balance: parseDecimalOrNull(json['balance']),
      credit: credit is Map<String, dynamic>
          ? CreditInfoDto.fromJson(credit)
          : null,
      outgoingTransfersAreIncome:
          json['outgoing_transfers_are_income'] as bool? ?? false,
      bankCode: json['bank_code'] as String?,
    );
  }

  final String id;
  final String userId;

  /// `BANK` or `CREDIT`.
  final String type;
  final String name;
  final String? marketingName;
  final String number;
  final Decimal? balance;
  final CreditInfoDto? credit;
  final bool outgoingTransfersAreIncome;
  final String? bankCode;
}
