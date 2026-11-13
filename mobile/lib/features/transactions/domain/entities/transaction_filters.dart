import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:mobile/features/transactions/domain/entities/transaction.dart';

/// Which filter a chip of the list stands for.
enum TransactionFilterKey {
  account,
  direction,
  status,
  dateFrom,
  dateTo,
  minAmount,
  maxAmount,
}

/// What the person chose in the filter sheet. Every field is optional: `null`
/// means "do not filter by it". The search text and the person are not here:
/// they have their own controls.
class TransactionFilters extends Equatable {
  const TransactionFilters({
    this.accountId,
    this.direction,
    this.status,
    this.dateFrom,
    this.dateTo,
    this.minAmount,
    this.maxAmount,
  });

  final String? accountId;
  final TransactionDirection? direction;
  final TransactionStatus? status;

  /// First day, both dates are whole days and inclusive.
  final DateTime? dateFrom;
  final DateTime? dateTo;

  /// Compared with the absolute amount.
  final Decimal? minAmount;
  final Decimal? maxAmount;

  /// The filter keys in use, in the order the chips show them.
  List<TransactionFilterKey> get activeKeys => [
    if (accountId != null) TransactionFilterKey.account,
    if (direction != null) TransactionFilterKey.direction,
    if (status != null) TransactionFilterKey.status,
    if (dateFrom != null) TransactionFilterKey.dateFrom,
    if (dateTo != null) TransactionFilterKey.dateTo,
    if (minAmount != null) TransactionFilterKey.minAmount,
    if (maxAmount != null) TransactionFilterKey.maxAmount,
  ];

  int get activeCount => activeKeys.length;

  bool get isEmpty => activeCount == 0;

  /// The same filters without one of them (the chip was removed).
  TransactionFilters without(TransactionFilterKey key) => TransactionFilters(
    accountId: key == TransactionFilterKey.account ? null : accountId,
    direction: key == TransactionFilterKey.direction ? null : direction,
    status: key == TransactionFilterKey.status ? null : status,
    dateFrom: key == TransactionFilterKey.dateFrom ? null : dateFrom,
    dateTo: key == TransactionFilterKey.dateTo ? null : dateTo,
    minAmount: key == TransactionFilterKey.minAmount ? null : minAmount,
    maxAmount: key == TransactionFilterKey.maxAmount ? null : maxAmount,
  );

  @override
  List<Object?> get props => [
    accountId,
    direction,
    status,
    dateFrom,
    dateTo,
    minAmount,
    maxAmount,
  ];
}
