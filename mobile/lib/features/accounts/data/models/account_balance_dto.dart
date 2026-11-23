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

/// The `next_bill` of a card inside `GET /bank-accounts/balances`.
class CardBillSummaryDto {
  const CardBillSummaryDto({
    required this.month,
    required this.total,
    required this.estimated,
  });

  /// Throws [FormatException] when a field is missing or invalid.
  factory CardBillSummaryDto.fromJson(Map<String, dynamic> json) {
    final text = requireString(json['month'], 'month');
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(text);
    final month = match == null ? 0 : int.parse(match.group(2)!);
    if (match == null || month < 1 || month > 12) {
      throw FormatException('Expected a month as yyyy-MM, got "$text".');
    }
    return CardBillSummaryDto(
      month: DateTime(int.parse(match.group(1)!), month),
      total: parseDecimal(json['total']),
      estimated: json['estimated'] as bool? ?? false,
    );
  }

  final DateTime month;
  final Decimal total;
  final bool estimated;
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
    this.nextBill,
  });

  /// Throws [FormatException] when a required field is missing or invalid.
  factory AccountBalanceDto.fromJson(Map<String, dynamic> json) {
    final credit = json['credit'];
    final nextBill = json['next_bill'];
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
      nextBill: nextBill is Map<String, dynamic>
          ? CardBillSummaryDto.fromJson(nextBill)
          : null,
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
  final CardBillSummaryDto? nextBill;
}
