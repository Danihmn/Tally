import 'package:decimal/decimal.dart';
import 'package:mobile/core/utils/json_parsing.dart';

/// A recurrence as `/recurrences` sends it.
class RecurrenceDto {
  const RecurrenceDto({
    required this.id,
    required this.description,
    required this.type,
    required this.paymentType,
    required this.amount,
    required this.dueDay,
    required this.category,
    required this.notes,
    required this.userId,
    required this.status,
  });

  /// Throws [FormatException] when a required field is missing or invalid.
  factory RecurrenceDto.fromJson(Map<String, dynamic> json) => RecurrenceDto(
    id: requireString(json['id'], 'id'),
    description: requireString(json['description'], 'description'),
    type: requireString(json['type'], 'type'),
    paymentType: json['payment_type'] as String?,
    amount: parseDecimal(json['amount']),
    dueDay: json['due_day'] as int?,
    category: json['category'] as String?,
    notes: json['notes'] as String?,
    userId: json['user_id'] as String?,
    status: json['status'] as String? ?? 'ACTIVE',
  );

  final String id;
  final String description;

  /// `REVENUES` or `EXPENSES`.
  final String type;

  /// `DEBIT`, `CREDIT` or missing.
  final String? paymentType;
  final Decimal amount;
  final int? dueDay;
  final String? category;
  final String? notes;

  /// The owner. `null` when that person is gone.
  final String? userId;

  /// `ACTIVE` or `CANCELLED`.
  final String status;
}

/// The answer of `POST /recurrences/provision`.
class ProvisionResultDto {
  const ProvisionResultDto({
    required this.referenceMonth,
    required this.created,
    required this.skipped,
  });

  factory ProvisionResultDto.fromJson(Map<String, dynamic> json) =>
      ProvisionResultDto(
        referenceMonth: parseApiDate(json['reference_month']),
        created: requireInt(json['created'], 'created'),
        skipped: requireInt(json['skipped'], 'skipped'),
      );

  final DateTime referenceMonth;
  final int created;
  final int skipped;
}
