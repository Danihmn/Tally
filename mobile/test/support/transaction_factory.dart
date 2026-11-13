import 'package:decimal/decimal.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';

/// A transaction with safe values. Pass only what the test cares about.
Transaction makeTransaction({
  String id = 't1',
  String accountId = 'a1',
  String ownerId = 'm1',
  DateTime? date,
  String? description = 'Mercado',
  String amount = '-100.00',
  TransactionDirection direction = TransactionDirection.debit,
  TransactionStatus status = TransactionStatus.posted,
  String? category,
  String? categoryId,
  String? merchantName,
  String? balance,
}) => Transaction(
  id: id,
  accountId: accountId,
  ownerId: ownerId,
  date: date ?? DateTime.utc(2026, 11, 5),
  description: description,
  amount: Decimal.parse(amount),
  direction: direction,
  status: status,
  category: category,
  categoryId: categoryId,
  merchantName: merchantName,
  balance: balance == null ? null : Decimal.parse(balance),
);
