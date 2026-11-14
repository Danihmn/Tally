import 'package:decimal/decimal.dart';
import 'package:mobile/core/utils/json_parsing.dart';

/// An entry as `GET /financial-entries` sends it.
class FinancialEntryDto {
  const FinancialEntryDto({
    required this.id,
    required this.userId,
    required this.bankAccountId,
    required this.description,
    required this.category,
    required this.type,
    required this.paymentType,
    required this.amount,
    required this.referenceMonth,
    required this.dueDate,
    required this.status,
    required this.installmentNumber,
    required this.installmentTotal,
    required this.notes,
    required this.createdAt,
  });

  /// Throws [FormatException] when a required field is missing or invalid.
  factory FinancialEntryDto.fromJson(Map<String, dynamic> json) =>
      FinancialEntryDto(
        id: requireString(json['id'], 'id'),
        userId: requireString(json['user_id'], 'user_id'),
        bankAccountId: json['bank_account_id'] as String?,
        description: requireString(json['description'], 'description'),
        category: json['category'] as String?,
        type: requireString(json['type'], 'type'),
        paymentType: json['payment_type'] as String?,
        amount: parseDecimal(json['amount']),
        referenceMonth: parseApiDate(json['reference_month']),
        dueDate: json['due_date'] == null
            ? null
            : parseApiDate(json['due_date']),
        status: requireString(json['status'], 'status'),
        installmentNumber: json['installment_number'] as int?,
        installmentTotal: json['installment_total'] as int?,
        notes: json['notes'] as String?,
        createdAt: parseDateTime(json['created_at']),
      );

  final String id;
  final String userId;
  final String? bankAccountId;
  final String description;
  final String? category;

  /// `REVENUES` or `EXPENSES`.
  final String type;

  /// `DEBIT`, `CREDIT` or missing.
  final String? paymentType;
  final Decimal amount;
  final DateTime referenceMonth;
  final DateTime? dueDate;

  /// `PLANNED`, `RECONCILED` or `CANCELLED`.
  final String status;
  final int? installmentNumber;
  final int? installmentTotal;
  final String? notes;
  final DateTime createdAt;
}

/// A page of `GET /financial-entries`: `{items, total, limit, offset}`.
class FinancialEntryPageDto {
  const FinancialEntryPageDto({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory FinancialEntryPageDto.fromJson(Map<String, dynamic> json) =>
      FinancialEntryPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            FinancialEntryDto.fromJson(item as Map<String, dynamic>),
        ],
        total: requireInt(json['total'], 'total'),
        limit: requireInt(json['limit'], 'limit'),
        offset: requireInt(json['offset'], 'offset'),
      );

  final List<FinancialEntryDto> items;
  final int total;
  final int limit;
  final int offset;
}
