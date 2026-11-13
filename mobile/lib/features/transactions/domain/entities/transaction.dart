import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

/// Money out (debit) or money in (credit).
enum TransactionDirection {
  debit('DEBIT'),
  credit('CREDIT');

  const TransactionDirection(this.apiValue);

  /// What the API sends and expects in the `type` field.
  final String apiValue;
}

/// Pending (the bank has not settled it yet) or posted.
enum TransactionStatus {
  posted('POSTED'),
  pending('PENDING');

  const TransactionStatus(this.apiValue);

  final String apiValue;
}

/// A bank transaction.
class Transaction extends Equatable {
  const Transaction({
    required this.id,
    required this.accountId,
    required this.ownerId,
    required this.date,
    required this.description,
    required this.amount,
    required this.direction,
    required this.status,
    required this.category,
    required this.categoryId,
    required this.merchantName,
    required this.balance,
  });

  final String id;
  final String accountId;

  /// The person who connected the bank of the account.
  final String ownerId;

  /// When the bank says it happened, in UTC.
  final DateTime date;
  final String? description;

  /// As the bank sends it: the sign is NOT the direction (on a credit card a
  /// purchase has a positive amount). Use [direction] and [absoluteAmount].
  final Decimal amount;
  final TransactionDirection direction;
  final TransactionStatus status;

  /// Text of the category as it is stored. It may be in English or be missing.
  final String? category;
  final String? categoryId;
  final String? merchantName;

  /// Balance of the account after this transaction, when the bank tells it.
  final Decimal? balance;

  bool get isIncome => direction == TransactionDirection.credit;

  bool get isPending => status == TransactionStatus.pending;

  Decimal get absoluteAmount => amount.abs();

  /// The amount with the sign of its direction: positive for money in and
  /// negative for money out. Used to add up a day.
  Decimal get signedAmount =>
      isIncome ? absoluteAmount : Decimal.zero - absoluteAmount;

  /// The calendar day of [date] in UTC (the day the bank gave), at midnight.
  /// It is not converted to the time zone of the phone, which could move it.
  DateTime get day {
    final utc = date.toUtc();
    return DateTime(utc.year, utc.month, utc.day);
  }

  @override
  List<Object?> get props => [
    id,
    accountId,
    ownerId,
    date,
    description,
    amount,
    direction,
    status,
    category,
    categoryId,
    merchantName,
    balance,
  ];
}
