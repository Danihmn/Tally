import 'package:decimal/decimal.dart';
import 'package:mobile/core/utils/json_parsing.dart';

/// One transaction inside `GET /bank-accounts/{id}/bill`.
class CardBillTransactionDto {
  const CardBillTransactionDto({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.status,
    required this.installmentNumber,
    required this.totalInstallments,
  });

  /// Throws [FormatException] when a required field is missing or invalid.
  factory CardBillTransactionDto.fromJson(Map<String, dynamic> json) =>
      CardBillTransactionDto(
        id: requireString(json['id'], 'id'),
        date: parseDateTime(json['date']),
        description: optionalString(json['description']),
        amount: parseDecimal(json['amount']),
        type: requireString(json['type'], 'type'),
        status: requireString(json['status'], 'status'),
        installmentNumber: json['installment_number'] as int?,
        totalInstallments: json['total_installments'] as int?,
      );

  final String id;
  final DateTime date;
  final String? description;
  final Decimal amount;

  /// `DEBIT` (purchase) or `CREDIT` (refund or credit).
  final String type;

  /// `POSTED` or `PENDING`.
  final String status;
  final int? installmentNumber;
  final int? totalInstallments;
}

/// The bill of a card as `GET /bank-accounts/{id}/bill` sends it.
class CardBillDto {
  const CardBillDto({
    required this.accountId,
    required this.month,
    required this.total,
    required this.estimated,
    required this.transactions,
  });

  /// Throws [FormatException] when a required field is missing or invalid.
  factory CardBillDto.fromJson(Map<String, dynamic> json) {
    final items = json['transactions'];
    return CardBillDto(
      accountId: requireString(json['account_id'], 'account_id'),
      month: _parseMonth(json['month']),
      total: parseDecimal(json['total']),
      estimated: json['estimated'] as bool? ?? false,
      transactions: [
        if (items is List)
          for (final item in items)
            CardBillTransactionDto.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  final String accountId;

  /// Day 1 of the due month (the API sends `YYYY-MM`).
  final DateTime month;
  final Decimal total;
  final bool estimated;
  final List<CardBillTransactionDto> transactions;
}

/// `2026-12` becomes 1 December 2026 (local midnight, so the month never moves).
DateTime _parseMonth(Object? value) {
  final match = value is String
      ? RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value)
      : null;
  final month = match == null ? 0 : int.parse(match.group(2)!);
  if (match == null || month < 1 || month > 12) {
    throw FormatException('Expected a month as yyyy-MM, got "$value".');
  }
  return DateTime(int.parse(match.group(1)!), month);
}
