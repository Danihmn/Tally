import 'package:decimal/decimal.dart';
import 'package:mobile/core/utils/json_parsing.dart';

/// A transaction as `GET /transactions` sends it.
class TransactionDto {
  const TransactionDto({
    required this.id,
    required this.bankAccountId,
    required this.userId,
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.status,
    required this.category,
    required this.categoryId,
    required this.merchantName,
    required this.balance,
  });

  /// Throws [FormatException] when a required field is missing or invalid.
  factory TransactionDto.fromJson(Map<String, dynamic> json) => TransactionDto(
    id: requireString(json['id'], 'id'),
    bankAccountId: requireString(json['bank_account_id'], 'bank_account_id'),
    userId: requireString(json['user_id'], 'user_id'),
    date: parseDateTime(json['date']),
    description: json['description'] as String?,
    amount: parseDecimal(json['amount']),
    type: requireString(json['type'], 'type'),
    status: requireString(json['status'], 'status'),
    category: json['category'] as String?,
    categoryId: json['category_id'] as String?,
    merchantName: _merchantName(json['merchant']),
    balance: parseDecimalOrNull(json['balance']),
  );

  final String id;
  final String bankAccountId;
  final String userId;
  final DateTime date;
  final String? description;
  final Decimal amount;

  /// `DEBIT` or `CREDIT`.
  final String type;

  /// `POSTED` or `PENDING`.
  final String status;
  final String? category;
  final String? categoryId;
  final String? merchantName;
  final Decimal? balance;

  /// The bank sends `merchant` as an object (`{name, businessName, ...}`) or
  /// not at all. The name is the only part the app shows.
  static String? _merchantName(Object? merchant) {
    if (merchant is Map<String, dynamic>) {
      for (final key in const ['name', 'businessName']) {
        final value = merchant[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
    return null;
  }
}

/// A page of `GET /transactions`: `{items, total, limit, offset}`.
class TransactionPageDto {
  const TransactionPageDto({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory TransactionPageDto.fromJson(Map<String, dynamic> json) =>
      TransactionPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            TransactionDto.fromJson(item as Map<String, dynamic>),
        ],
        total: requireInt(json['total'], 'total'),
        limit: requireInt(json['limit'], 'limit'),
        offset: requireInt(json['offset'], 'offset'),
      );

  final List<TransactionDto> items;
  final int total;
  final int limit;
  final int offset;
}
