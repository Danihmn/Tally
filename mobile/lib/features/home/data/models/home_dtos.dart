import 'package:decimal/decimal.dart';
import 'package:mobile/core/utils/json_parsing.dart';

/// An endpoint that answers one amount: `{date_from, date_to, <key>}`, where
/// the key is `total`, `balance` or `average`.
class AmountDto {
  const AmountDto({required this.value});

  /// Throws [FormatException] when [key] is missing or is not an amount.
  factory AmountDto.fromJson(
    Map<String, dynamic> json, {
    required String key,
  }) => AmountDto(value: parseDecimal(json[key]));

  final Decimal value;
}

/// One day of `GET /transactions/daily-expenses`.
class DailyAmountDto {
  const DailyAmountDto({required this.date, required this.total});

  factory DailyAmountDto.fromJson(Map<String, dynamic> json) => DailyAmountDto(
    date: parseApiDate(json['date']),
    total: parseDecimal(json['total']),
  );

  final DateTime date;
  final Decimal total;
}

/// One item of `GET /transactions/top-expenses`.
class TopExpenseDto {
  const TopExpenseDto({
    required this.date,
    required this.amount,
    required this.description,
  });

  factory TopExpenseDto.fromJson(Map<String, dynamic> json) => TopExpenseDto(
    date: parseApiDate(json['date']),
    amount: parseDecimal(json['amount']),
    description: json['description'] as String?,
  );

  final DateTime date;
  final Decimal amount;
  final String? description;
}

/// `GET /financial-entries/reconciliation-counts`.
class ReconciliationCountsDto {
  const ReconciliationCountsDto({
    required this.reconciled,
    required this.notReconciled,
  });

  factory ReconciliationCountsDto.fromJson(Map<String, dynamic> json) =>
      ReconciliationCountsDto(
        reconciled: requireInt(json['reconciled'], 'reconciled'),
        notReconciled: requireInt(json['not_reconciled'], 'not_reconciled'),
      );

  final int reconciled;
  final int notReconciled;
}

/// One item of `GET /financial-entries/upcoming`.
class UpcomingEntryDto {
  const UpcomingEntryDto({
    required this.description,
    required this.amount,
    required this.type,
    required this.category,
    required this.dueDate,
  });

  /// `category` is optional: it may be `null`, and an older API leaves it out.
  factory UpcomingEntryDto.fromJson(Map<String, dynamic> json) =>
      UpcomingEntryDto(
        description: requireString(json['description'], 'description'),
        amount: parseDecimal(json['amount']),
        type: requireString(json['type'], 'type'),
        category: json['category'] as String?,
        dueDate: parseApiDate(json['due_date']),
      );

  final String description;
  final Decimal amount;

  /// `REVENUES` or `EXPENSES`.
  final String type;
  final String? category;
  final DateTime dueDate;
}
